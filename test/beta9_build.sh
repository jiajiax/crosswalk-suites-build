#!/bin/bash

. /etc/profile
export PATH=/usr/tizen-sdk/tools:/usr/java/sdk/tools:/usr/java/sdk/platform-tools:/usr/java/jdk1.7.0_67/bin:/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/games:/usr/local/games
script_dir=$(dirname $(readlink -f $0))
cts_dir=$script_dir/../work_space/release/beta-crosswalk-test-suite
WW_dir=$script_dir/WWbeta
demoex_dir=$cts_dir/../demo-express
log_dir=$script_dir/logs
version_file=$script_dir/Beta9_Number
pkg_tools=$cts_dir/../pkg_tools
source $script_dir/beta9_list

sample_list=""

version_num=`cat $version_file`

function init_ww(){
    mkdir -p $WW_dir/{android/{all-in-one/{arm,x86},cordova/{arm,x86},separate/{x86,arm},embeddingapi/{x86,arm}},tizen}
}

function prepare_tools(){
    cd $cts_dir/tools
    rm -rf crosswalk cordova crosswalk-webview XWalkRuntimeLib.apk
    if [ $# -eq 1 ];then
        if [ -f $pkg_tools/crosswalk-apks-$version_num-$1/XWalkRuntimeLib.apk ];then
            cp $pkg_tools/crosswalk-apks-$version_num-$1/XWalkRuntimeLib.apk .  
        else
            echo "crosswalk-apks-$version_num-$1/XWalkRuntimeLib.apk not exist !!!" >> $log_dir/tools_error.log
            exit 1
        fi
    
        if [ -d $pkg_tools/crosswalk-cordova-$version_num-$1 ];then
            cp -a $pkg_tools/crosswalk-cordova-$version_num-$1 cordova
        else
            echo "crosswalk-cordova-$version_num-$1 not exist !!!" >> $log_dir/tools_error.log
            exit 1
    
        fi
    
        if [ -d $pkg_tools/crosswalk-$version_num ];then
            cp -a $pkg_tools/crosswalk-$version_num crosswalk
        else
            echo "$pkg_tools/crosswalk-$version_num not exist !!!" >> $log_dir/tools_error.log
            exit 1
    
        fi

        if [ -d $pkg_tools/crosswalk-webview-$version_num-$1 ];then
            cp -a $pkg_tools/crosswalk-webview-$version_num-$1 crosswalk-webview
        else
            echo "$pkg_tools/crosswalk-webview-$version_num-$1 not exist !!!" >> $log_dir/tools_error.log
            exit 1
    
        fi

    else
        echo "arguments error !!!"
    fi  
    

}

function sync_code(){
    # Get latest code from github
	find $WW_dir -type f -name "*.zip" | xargs rm -f
	cd $cts_dir ;git reset --hard HEAD;git checkout Crosswalk-9;git pull 
    beta_commit=`git log -1 --pretty=oneline | awk '{print $1}'`
    beta_branch=`git branch | grep -E "^\*" | awk '{print $2}'`
    cd -
}

function updateVersionNum(){
  
    sed -i "s|\"main-version\": \"\([^\"]*\)\"|\"main-version\": \"$version_num\"|g" $cts_dir/VERSION
	# clean WW dir
	find $WW_dir -type f -delete
	# modify pack.py
	#sed -i '688s/orig_dir/app_src/' $cts_dir/tools/build/pack.py
	#sed -i '567,569s/^/#/' $cts_dir/tools/build/pack.py
	#sed '' $cts_dir/tools/build/pack.py
	
}

function webapi_usecase_pro(){
    if [ $1 = "webapi-usecase-tests" ];then

        echo "process webapi-usecase-tests start..."
        sample_list=`ls $demoex_dir/samples/`
        cp -dpRv $demoex_dir/samples/* $2/samples/
        sed -i -e '/<\/suite/d ;/<\/test_definition/d' $2/tests.android.xml && sed -n '1,/<set name\=\"Third Party Framework/p' $demoex_dir/tests.android.xml | sed '$d' | sed -n '/<set/,$p' >> $2/tests.android.xml && tail -n2 $demoex_dir/tests.android.xml >> $2/tests.android.xml
        sed -i -e '/<\/suite/d ;/<\/test_definition/d' $2/tests.tizen.xml && sed -n '/<set/,$p' $demoex_dir/tests.tizen.xml >> $2/tests.tizen.xml

    elif [ $1 = "wrt-usecase-android-tests" ];then

        echo "process wrt-usecase-android-tests start..."
        sample_list=`ls $demoex_dir/samples-wrt/`
        cp -dpRv $demoex_dir/samples-wrt/* $2/tests/
        sed -i -e '/<\/suite/d ;/<\/test_definition/d' $2/tests.android.xml && sed -n '/<set name\=\"Third Party Framework/,$p' $demoex_dir/tests.android.xml >> $2/tests.android.xml
    
    fi  

}

function cancel_xml(){

    if [ $1 = "webapi-usecase-tests" ];then
        cd $2/samples
        #cd samples
        rm -rf $sample_list
        cd -

        cd $2
        rm -f tests.android.xml tests.tizen.xml
        git checkout tests.android.xml
        git checkout tests.tizen.xml 
        cd -
    elif [ $1 = "wrt-usecase-android-tests" ];then
        cd $2/tests/
        rm -rf $sample_list
        cd -

        cd $2
        rm -f tests.android.xml tests.tizen.xml
        git checkout tests.android.xml
        git checkout tests.tizen.xml
        cd -
    fi  
}


function pack_wgt ()
{
    for wgt in $WGTLIST;do
        num=`find $cts_dir -name $wgt -type d |wc -l`
        if [ $num -eq 1 ];then
            wgt_dir=`find $cts_dir -name $wgt -type d`
	    #cancel_xml $wgt $wgt_dir
	    #webapi_usecase_pro $wgt $wgt_dir
            $cts_dir/tools/build/pack.py -t wgt -s $wgt_dir -d $WW_dir/tizen/wgt --tools=$cts_dir/tools
            if [ $? -ne 0 ];then
                echo "$wgt failed">>$script_dir/error.log
            fi
	    #cancel_xml $wgt $wgt_dir
            echo $wgt_dir
        else
            echo "$wgt Not unique"    
        fi
    done
}

function pack_xpk ()
{
    for xpk in $XPKLIST;do
        num=`find $cts_dir -name $xpk -type d |wc -l`
        if [ $num -eq 1 ];then
            xpk_dir=`find $cts_dir -name $xpk -type d`
            $cts_dir/tools/build/pack.py -t xpk -s $xpk_dir -d $WW_dir/tizen/wgt --tools=$cts_dir/tools
            if [ $? -ne 0 ];then
                echo "$xpk failed">>$script_dir/error.log
            fi
            echo $xpk_dir
        else
            echo "$xpk Not unique"    
        fi
    done
}


function pack_apk_x86 ()
{
	prepare_tools x86
    for apk_x86 in $APKLIST;do
        num=`find $cts_dir -name $apk_x86 -type d |wc -l`
        if [ $num -eq 1 ];then
            apk_x86_dir=`find $cts_dir -name $apk_x86 -type d`
	    #cancel_xml $apk_x86 $apk_x86_dir
	    #webapi_usecase_pro $apk_x86 $apk_x86_dir
            $cts_dir/tools/build/pack.py -t apk -m embedded -a x86 -s $apk_x86_dir -d $WW_dir/android/separate/x86 --tools=$cts_dir/tools
            if [ $? -ne 0 ];then
                echo "$apk_x86 failed">>$script_dir/error.log
            fi
	    #cancel_xml $apk_x86 $apk_x86_dir
            echo $apk_x86_dir
        else
            echo "$apk_x86 Not unique"    
        fi
    done
}
function pack_apk_arm ()
{
	prepare_tools arm
    for apk_arm in $APKLIST;do
        num=`find $cts_dir -name $apk_arm -type d |wc -l`
        if [ $num -eq 1 ];then
            apk_arm_dir=`find $cts_dir -name $apk_arm -type d`
	    #cancel_xml $apk_arm $apk_arm_dir
	    #webapi_usecase_pro $apk_arm $apk_arm_dir
            $cts_dir/tools/build/pack.py -t apk -m embedded -a arm -s $apk_arm_dir -d $WW_dir/android/separate/arm --tools=$cts_dir/tools
            if [ $? -ne 0 ];then
                echo "$apk_arm failed">>$script_dir/error.log
            fi
	    #cancel_xml $apk_arm $apk_arm_dir
            echo $apk_arm_dir
        else
            echo "$apk_arm Not unique"    
        fi
    done
}

function pack_embeddingapi ()
{
    prepare_tools $1  
    for emb_pkg in $EMBEDDINGLIST;do
        num=`find $cts_dir -name $emb_pkg -type d |wc -l`
        if [ $num -eq 1 ];then

            emb_pkg_dir=`find $cts_dir -name $emb_pkg -type d`
            rm -rf $emb_pkg_dir/embeddingapi
            rm -f $emb_pkg_dir/suite.json $emb_pkg_dir/inst.apk.py
            cp $emb_pkg_dir/tmp/* $emb_pkg_dir/
            if [ $emb_pkg = "webapi-embeddingapi-xwalk-tests" ];then
                rm -f $emb_pkg_dir/libs/*.jar
                jarlist=`find $emb_pkg_dir/libs/ -type f -name "*.jar" | xargs`
                cp $jarlist $emb_pkg_dir/libs/
            fi
            flist=`find $emb_pkg_dir -maxdepth 1 -mindepth 1 -type d`
            mkdir -p $emb_pkg_dir/embeddingapi
            cp -r $flist $emb_pkg_dir/embeddingapi/
            cp $emb_pkg_dir/AndroidManifest.xml $emb_pkg_dir/embeddingapi/
    
        #cancel_xml $apk_x86 $apk_x86_dir
        #webapi_usecase_pro $apk_x86 $apk_x86_dir
            $cts_dir/tools/build/pack.py -t embeddingapi -s $emb_pkg_dir -d $WW_dir/android/embeddingapi/$1 --tools=$cts_dir/tools
            if [ $? -ne 0 ];then
                echo "$emb_pkg failed">>$script_dir/logs/beta9_error.log
            fi
        #cancel_xml $apk_x86 $apk_x86_dir
            rm -rf $emb_pkg_dir/embeddingapi
            rm -f $emb_pkg_dir/suite.json $emb_pkg_dir/inst.apk.py
            rm -f $emb_pkg_dir/libs/*.jar
            echo $emb_pkg_dir
        else
            echo "$emb_pkg Not unique"    
        fi
    done
}


function pack_cordova_arm(){
	prepare_tools arm
    for cordova_arm in $CORDOVALIST;do
        num=`find $cts_dir -name $cordova_arm -type d |wc -l`
		echo $num
        if [ $num -eq 1 ];then
            cordova_arm_dir=`find $cts_dir -name $cordova_arm -type d`
	    	if [ $cordova_arm = "webapi-usecase-tests" ];then
				sed -i '33i\    <uses-permission android:name="android.permission.CAMERA" />' $cts_dir/tools/cordova/bin/templates/project/AndroidManifest.xml
	    	fi
	    	#cancel_xml $cordova_arm $cordova_arm_dir
	    	#webapi_usecase_pro $cordova_arm $cordova_arm_dir
            $cts_dir/tools/build/pack.py -t cordova -s $cordova_arm_dir -d $WW_dir/android/cordova/arm
            if [ $? -ne 0 ];then
                echo "$cordova_arm failed">>$script_dir/error.log
            fi
            echo $cordova_arm_dir
	    	if [ $cordova_arm = "webapi-usecase-tests" ];then
	        	sed -i '33d' $cts_dir/tools/cordova/bin/templates/project/AndroidManifest.xml
	    	fi
	    	echo "*************************************************"
	    	#cancel_xml $cordova_arm $cordova_arm_dir
	    	echo "*************************************************"
        else
            echo "$cordova_arm Not unique"    
        fi
    done
}
function pack_aio ()
{
	prepare_tools $1
    for aio in $AIOLIST;do
        num=`find $cts_dir -name $aio -type d |wc -l`
        if [ $num -eq 1 ];then
            aio_dir=`find $cts_dir -name $aio -type d`
            cd $aio_dir
            ./pack.sh -a $1
            if [ $? -ne 0 ];then
                echo "$aio_$1 failed">>$script_dir/error.log
            fi
            mv *.zip $WW_dir/android/all-in-one/$1
            cd -
        else
            echo "$aio_$1 Not unique"    
        fi
    done
}

echo "" > $script_dir/error.log

function save_package(){ 
    end_time=`date +%m-%d-%H%M` 
    cp -a $WW_dir $WW_dir/../beta_WW_list/$version_num"~"$end_time
    wweek=$(date +"%W" -d "+1 weeks")
    wtoday=$[$(date +%w)]
    wdir="WW"$wweek
    
    mkdir -p /mnt/otcqa/$wdir/{beta/"ww"$wweek"."$wtoday,master,stable,webtestingservice}
    if [ $? -eq 0 ];then
        cp -a $WW_dir /mnt/otcqa/$wdir/beta/"ww"$wweek"."$wtoday/"ww"$version_num"~"$end_time
		chmod -R 775 /mnt/otcqa/$wdir/beta/"ww"$wweek"."$wtoday/"ww"$version_num"~"$end_time
    fi  
 
    pkgaddress=$wdir/beta/"ww"$wweek"."$wtoday/"ww"$version_num"~"$end_time
    python /home/carry/00_jiajia/release_build/smail.py $version_num $pkgaddress $beta_commit $beta_branch
}

init_ww
sync_code
updateVersionNum
#pack_wgt
#pack_xpk
pack_cordova_arm
pack_apk_x86
pack_apk_arm
pack_aio x86
pack_aio arm
pack_embeddingapi x86
pack_embeddingapi arm
save_package
