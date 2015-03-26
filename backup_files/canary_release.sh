#!/bin/bash

. /etc/profile
export PATH=/usr/java/sdk//tools:/usr/java/sdk//platform-tools:/usr/java/jdk1.7.0_67//bin:/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/games:/usr/local/games
script_dir=$(dirname $(readlink -f $0))
shared_dir=/mnt/jiajiax_shared/release
cts_dir=$script_dir/../work_space/release/crosswalk-test-suite
demoex_dir=$cts_dir/../demo-express
log_dir=$script_dir/logs
release_commit=$log_dir/$(date +%Y-%m-%d-%T)_release
version_file=$script_dir/version_flag/Canary_New_Number
pkg_tools=$cts_dir/../pkg_tools/
source $script_dir/list_suites/release_list
sample_list=""
branch_master="master"

wweek=$(date +"%W" -d "+1 weeks")
WW_dir=$script_dir/"WW"$wweek


while true;do
	flag=$(ls -al $version_file | awk '{print $7}')
	now=`date +%d`
    num3=$(ps -ef | grep -c "beta12_build.sh")
    num4=$(ps -ef | grep -c "beta10_build.sh")
    num2=$(ps -ef | grep -c "beta11_build.sh")
    sum=$[$num2+$num3+$num4]
	if [ $flag -eq $now ] && [ $sum -le 3 ];then
		echo "Release Begin..."
        echo "$num2 $num3 $num4"
		break
	else
		hour_now=`date +%H`
		if [ $hour_now -ge 9 ];then
			exit 1
		fi
		sleep 10m
		
	fi
done


version_num=`cat $version_file`
#version_num='12.40.284.0'

init_ww(){
    rm -rf $WW_dir
    mkdir -p "WW"$wweek/{android/{all-in-one/{arm,x86},cordova/{arm,x86},separate/{arm,x86},embeddingapi/{x86,arm}},tizen/{wgt,xpk,xpk-generic},tizen-tct/wgt}
    mkdir -p $WW_dir/{Android/{Canary-Release/$version_num/{Embedded_Tests/{x86,arm},Shared_Tests/{x86,arm},Cordova_Tests/{x86,arm},Crosswalk-Tools},Beta},Tizen}
    embedded_dir=$WW_dir/Android/Canary-Release/$version_num/Embedded_Tests/
    shared_dir=$WW_dir/Android/Canary-Release/$version_num/Shared_Tests/
    cordova_tests_dir=$WW_dir/Android/Canary-Release/$version_num/Shared_Tests/
    declare -A suite_path_arr
    suite_path_arr=([embedded]=$embedded_dir [shared]=$shared_dir)
}

prepare_tools(){
    cd $cts_dir/tools
    if [ $# -eq 2 ];then
        if [[ $2 == "apk" ]];then
            if [ -f $pkg_tools/crosswalk-apks-$version_num-$1/XWalkRuntimeLib.apk ];then
                rm -rf XWalkRuntimeLib.apk
                cp $pkg_tools/crosswalk-apks-$version_num-$1/XWalkRuntimeLib.apk .  
            else
                echo "crosswalk-apks-$version_num-$1/XWalkRuntimeLib.apk not exist !!!" >> $log_dir/canary_error.log
                echo "***********************************crosswalk-apks-$version_num-$1/XWalkRuntimeLib.apk not exist !!!***********************************"
                exit 1
            fi

            if [ -d $pkg_tools/crosswalk-$version_num ];then
                rm -rf crosswalk
                cp -a $pkg_tools/crosswalk-$version_num crosswalk
            else
                echo "crosswalk-$version_num not exist !!!" >> $log_dir/canary_error.log
                echo "**************************************crosswalk-$version_num not exist !!!*******************************************"
                exit 1
    
            fi
        fi

        if [[ $2 == "cordova" ]];then   
            if [ -d $pkg_tools/crosswalk-cordova-$version_num-$1 ];then
                rm -rf cordova
                cp -a $pkg_tools/crosswalk-cordova-$version_num-$1 cordova
            else
                echo "crosswalk-cordova-$version_num-$1 not exist !!!" >> $log_dir/canary_error.log
                echo "***********************************crosswalk-cordova-$version_num-$1 not exist !!!*****************************************"
                exit 1
    
            fi
        fi

        if [[ $2 == "embeddingapi" ]];then 
            if [ -d $pkg_tools/crosswalk-webview-$version_num-$1 ];then
                rm -rf crosswalk-webview
                cp -a $pkg_tools/crosswalk-webview-$version_num-$1 crosswalk-webview
            else
                echo "$pkg_tools/crosswalk-webview-$version_num-$1 not exist !!!" >> $log_dir/canary_error.log
                echo "*****************************************$pkg_tools/crosswalk-webview-$version_num-$1 not exist !!!***************************************"
                exit 1
    
            fi
        fi

    else
        echo "arguments error !!!"
    fi  
    
}


sync_code(){
    # Get latest code from github
	cd $demoex_dir ; git reset --hard HEAD ;git checkout master ;git pull ;cd -
	#cd $cts_dir ; git reset --hard HEAD; git checkout master; cd -
	if [ $(date +%w) -eq 3 ];then
        cd $cts_dir
        git reset --hard HEAD
        git checkout master
        git pull
        echo "---------- Release Commit -------">>$release_commit
        git log -1 --name-status >>$release_commit
        echo "---------------------------------">>$release_commit
        git log -1 --pretty=oneline | awk '{print $1}' > $shared_dir/Release_ID
        #cat $script_dir/Release_ID > /mnt/doc/tojiajia/flag/Release_ID
        cd -
        Wweek=$(date +"%W" -d "+1 weeks")
        cat $release_commit | mutt -s "$Wweek Week Release Commit" jiajiax.li@intel.com
    else
        release_id=`cat $shared_dir/Release_ID`
        cd $cts_dir ; git reset --hard HEAD;git checkout master;git pull ;git reset --hard $release_id;cd -
	fi
}

updateVersionNum(){
  
    sed -i "s|\"main-version\": \"\([^\"]*\)\"|\"main-version\": \"$version_num\"|g" $cts_dir/VERSION
}


uniq_id(){
    for xml_file in $@;do
        repeated_id_list=`grep "id=\"" $xml_file | awk -F'id=' '{print $2}' | awk -F'"' '{print $2}' | uniq -d`
        if [ X"$repeated_id_list" != "X" ];then
            for repeated_id in $repeated_id_list;do
                re_lnum=$(sed -n "/id=\"$repeated_id\"/{/execution_type=\"manual\"/=}" $xml_file)
                re_lnum2=$[$re_lnum+1]
                sed -i "${re_lnum},${re_lnum2}d" $xml_file
            done

        fi
    done

}

merge_xml(){
    if [ $1 = "usecase-webapi-xwalk-tests" ];then

        echo "process usecase-webapi-xwalk-tests start..."
		cp -dpRv $demoex_dir/samples/* $2/samples/
        cp -dpRv $demoex_dir/res/* $2/res/
		#sed -i -e '/<\/suite/d ;/<\/test_definition/d' $2/tests.android.xml && sed -n '1,/<set name="Third Party Framework" /p' $demoex_dir/tests.android.xml | sed '$d' | sed -n '/<set/,$p' >> $2/tests.android.xml && tail -n2 $demoex_dir/tests.android.xml >> $2/tests.android.xml
		#sed -i -e '/<\/suite/d ;/<\/test_definition/d' $2/tests.tizen.xml && sed -n '/<set/,$p' $demoex_dir/tests.tizen.xml >> $2/tests.tizen.xml
        #uniq_id $2/tests.android.xml $2/tests.tizen.xml

	elif [ $1 = "usecase-wrt-android-tests" ];then

		echo "process usecase-wrt-android-tests start..."
		cp -dpRv $demoex_dir/samples-wrt/* $2/samples/
		#sed -i -e '/<\/suite/d ;/<\/test_definition/d' $2/tests.android.xml && sed -n '/<set name="Third Party Framework" /,${/<!--/,/-->/d;p}' $demoex_dir/tests.android.xml >> $2/tests.android.xml
        #uniq_id $2/tests.android.xml
    elif [ $1 = "usecase-cordova-android-tests" ];then
        echo "process usecase-cordova-android-tests..."
        cp -dpRv $demoex_dir/samples-cordova/* $2/samples/
        #sed -i -e '/<\/suite>/d;/<\/test_definition>/d' $2/tests.xml && sed -n '/<set name="Cordova" /,${/-->/d;p}' $demoex_dir/tests.android.xml >> $2/tests.xml
        #uniq_id $2/tests.xml
		
    fi

}


cancel_xml(){

    if [ $1 = "usecase-webapi-xwalk-tests" ];then
        sample_list=`ls $demoex_dir/samples/`
		cd $2/samples/
		#cd samples
		rm -rf $sample_list
        git checkout .
		cd -

        cd $2/res/
        git clean -dfx .
        git checkout .
        cd -

		#cd $2
		#rm -f tests.android.xml tests.tizen.xml
		#git checkout tests.android.xml
		#git checkout tests.tizen.xml 
		#cd -
	elif [ $1 = "usecase-wrt-android-tests" ];then
        sample_list=`ls $demoex_dir/samples-wrt/`
		cd $2/samples/
		rm -rf $sample_list
        git checkout .
		cd -

		#cd $2
		#rm -f tests.android.xml
		#git checkout tests.android.xml
		#cd -
    elif [ $1 = "usecase-cordova-android-tests" ];then
        sample_list=`ls $demoex_dir/samples-cordova/`
        cd $2/samples/
        rm -rf $sample_list
        git checkout .
        cd -

        #cd $2
        #rm -f tests.xml
        #git checkout tests.xml
        #cd -
    fi
}

pack_wgt()
{
    for wgt in $WGTLIST;do
        num=`find $cts_dir -name $wgt -type d |wc -l`
        if [ $num -eq 1 ];then
            wgt_dir=`find $cts_dir -name $wgt -type d`
	    cancel_xml $wgt $wgt_dir
	    merge_xml $wgt $wgt_dir
            $cts_dir/tools/build/pack.py -t wgt -s $wgt_dir -d $WW_dir/tizen/wgt --tools=$cts_dir/tools
            if [ $? -ne 0 ];then
                echo "[wgt] <$wgt> failed">>$script_dir/logs/canary_error.log
            fi
	    cancel_xml $wgt $wgt_dir
            echo $wgt_dir
        else
            echo "$wgt Not unique" >> $log_dir/canary_error.log 
        fi
    done
}

pack_xpk()
{
    for xpk in $XPKLIST;do
        num=`find $cts_dir -name $xpk -type d |wc -l`
        if [ $num -eq 1 ];then
            xpk_dir=`find $cts_dir -name $xpk -type d`
            $cts_dir/tools/build/pack.py -t xpk -s $xpk_dir -d $WW_dir/tizen/wgt --tools=$cts_dir/tools
            if [ $? -ne 0 ];then
                echo "[xpk] <$xpk> failed" >> $log_dir/canary_error.log
            fi
            echo $xpk_dir
        else
            echo "$xpk Not unique" >> $log_dir/canary_error.log 
        fi
    done
}

pack_apk()
{
    prepare_tools $1 apk
    for apk in $APKLIST;do
        num=`find $cts_dir -name $apk -type d |wc -l`
        if [ $num -eq 1 ];then
            apk_dir=`find $cts_dir -name $apk -type d`
            cancel_xml $apk $apk_dir
            merge_xml $apk $apk_dir
            $cts_dir/tools/build/pack.py -t apk -m $2 -a $1 -s $apk_dir -d ${suite_path_arr[$2]}/$1
            if [ $? -ne 0 ];then
                echo "[apk][$1][$2] <${apk}> failed" >> $log_dir/canary_error.log
            fi
            cancel_xml $apk $apk_dir
            echo $apk_dir
        else
            echo "$apk Not unique" >> $log_dir/canary_error.log 
        fi
    done
}

pack_cordova()
{
	prepare_tools $1 cordova
    for cordova_suite in $CORDOVALIST;do
        num=`find $cts_dir -name $cordova_suite -type d |wc -l`
        if [ $num -eq 1 ];then
            cordova_suite_dir=`find $cts_dir -name $cordova_suite -type d`
	        if [ $cordova_suite = "usecase-webapi-xwalk-tests" ];then
                sed -i '33i\    <uses-permission android:name="android.permission.CAMERA" />' $cts_dir/tools/cordova/bin/templates/project/AndroidManifest.xml
	        fi
	        cancel_xml $cordova_suite $cordova_suite_dir
	        merge_xml $cordova_suite $cordova_suite_dir
            $cts_dir/tools/build/pack.py -t cordova -s $cordova_suite_dir -d $cordova_tests_dir/$1
            if [ $? -ne 0 ];then
                echo "[cordova][arm] <$cordova_suite> failed" >> $log_dir/canary_error.log
            fi
	        if [ $cordova_suite = "usecase-webapi-xwalk-tests" ];then
	            sed -i '33d' $cts_dir/tools/cordova/bin/templates/project/AndroidManifest.xml
	        fi
	        echo "*************************************************"
	        cancel_xml $cordova_suite $cordova_suite_dir
	        echo "*************************************************"
        else
            echo "$cordova_suite Not unique" >> $log_dir/canary_error.log   
        fi
    done
}


pack_embeddingapi()
{
    prepare_tools $1 embeddingapi
    for emb_pkg in $EMBEDDINGLIST;do
        num=`find $cts_dir -name $emb_pkg -type d |wc -l`
        if [ $num -eq 1 ];then
            emb_pkg_dir=`find $cts_dir -name $emb_pkg -type d`
            if [ $2 = "shared" ];then
                find $cts_dir/tools/crosswalk-webview/ -name "libxwalkcore.so" -exec rm -f {} \;
                find $cts_dir/tools/crosswalk-webview/ -name "xwalk_core_library_java_library_part.jar" -exec rm -f {} \;
                $cts_dir/tools/build/pack.py -t embeddingapi -s $emb_pkg_dir -d $shared_dir/$1 --tools=$cts_dir/tools
            elif [ $2 = "embedded" ];then
                $cts_dir/tools/build/pack.py -t embeddingapi -s $emb_pkg_dir -d $embedded_dir/$1 --tools=$cts_dir/tools
            fi
            if [ $? -ne 0 ];then
                echo "$emb_pkg failed" >> $log_dir/canary_error.log
            fi

            echo $emb_pkg_dir
        else
            echo "$emb_pkg Not unique" >> $log_dir/canary_error.log 
        fi
    done
}


pack_aio(){
	prepare_tools $1 apk
    prepare_tools $1 cordova
    for aio in $AIOLIST;do
        num=`find $cts_dir -name $aio -type d |wc -l`
        if [ $num -eq 1 ];then
            aio_dir=`find $cts_dir -name $aio -type d`
            cd $aio_dir
            ./pack.sh -a $1 -m $2
            if [ $? -ne 0 ];then
                echo "[webapi all-in-one][$1] <$aio> failed" >> $log_dir/canary_error.log
            fi
            mv *.zip ${suite_path_arr[$2]}/$1
            if [ $2 = "embedded" ];then
                ./pack.sh -t cordova
                if [ $? -ne 0 ];then
                    echo "[cordova all-in-one][$1] <$aio> failed" >> $log_dir/canary_error.log
                fi
                mv *.zip $cordova_tests_dir/$1
            fi
            cd -
        else
            echo "$aio_$1 Not unique" >> $log_dir/canary_error.log 
        fi
    done
}

save_package(){
	end_time=`date +%m-%d-%H%M`
	cp -a $WW_dir /data/pkgs/canary_WW_pkgs/$version_num"~"$end_time
    chmod -R 777 /data/pkgs/canary_WW_pkgs/$version_num"~"$end_time
    wtoday=$[$(date +%w)]
    wdir="WW"$wweek

    mkdir -p /mnt/otcqa/$wdir/{master/"ww"$wweek"."$wtoday,beta/"ww"$wweek"."$wtoday,stable,webtestingservice}
    if [ $wtoday -eq 5 ];then
        cp -a /data/pkgs/canary_WW_pkgs/$version_num"~"$end_time /mnt/otcqa/$wdir/master/"ww"$wweek"."$wtoday/FullTest
        chmod -R 775 /mnt/otcqa/$wdir/master/"ww"$wweek"."$wtoday/FullTest
        pkgaddress=$wdir/master/"ww"$wweek"."$wtoday/FullTest
        python $script_dir/smail.py $version_num $pkgaddress $release_id $branch_master
    fi
}

check_suite(){
    
    echo $1 $2

}

echo "" > $log_dir/canary_error.log
init_ww
sync_code
updateVersionNum
pack_wgt
pack_xpk
pack_cordova x86
pack_cordova arm
pack_apk x86 embedded
pack_apk x86 shared
pack_apk arm embedded
pack_apk arm shared
pack_aio x86 embedded
pack_aio x86 shared
pack_aio arm embedded
pack_aio arm shared
pack_embeddingapi x86 embedded
pack_embeddingapi x86 shared
pack_embeddingapi arm embedded
pack_embeddingapi arm shared
save_package
