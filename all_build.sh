#!/bin/bash

. /etc/profile
export PATH=/usr/java/sdk/tools:/usr/java/sdk/platform-tools:/usr/java/jdk1.7.0_67/bin:/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/games:/usr/local/games

script_dir=$(dirname $(readlink -f $0))
#demoex_dir=$cts_dir/../demo-express
log_dir=$script_dir/logs
flag_dir=$script_dir/version_flag
#pkg_tools=$cts_dir/../pkg_tools
sample_list=""

init_dir(){
    wweek=$(date +"%W" -d "+1 weeks")
    rm -rf $script_dir/"WW"$wweek
    mkdir -p $script_dir/"WW"$wweek/{test_plan,embedded_mode/{x86,arm},shared_mode/{master/{x86,arm},Crosswalk-11/{x86,arm},Crosswalk-10/{x86,arm},Crosswalk-9/{x86,arm}}}
    WW_dir=$script_dir/"WW"$wweek
}

init_dir

prepare_env(){
    demoex_dir=$cts_dir/../demo-express
    pkg_tools=$cts_dir/../pkg_tools
}

get_vnum(){
    sdk_num=`echo $1 | awk -F. '{print $1}'`
    cd $2
    branch_name=`git branch | awk '$1=="*"{print $2}'`
    if [[ $branch_name =~ "Crosswalk" ]];then
        branch_num=`echo $branch_name | awk -F'-' '{print $2}'`
    else
        branch_num=12
    fi
    
    vnum="$3""$wweek"-"$sdk_num"'.'"$branch_num"
    
    echo $vnum
}

prepare_tools(){
    cd $cts_dir/tools
    rm -rf crosswalk cordova crosswalk-webview XWalkRuntimeLib.apk
    if [ $# -eq 2 ];then
        if [ -f $pkg_tools/crosswalk-apks-$1-$2/XWalkRuntimeLib.apk ];then
            cp $pkg_tools/crosswalk-apks-$1-$2/XWalkRuntimeLib.apk . 
        else
            echo "crosswalk-apks-$1-$2/XWalkRuntimeLib.apk not exist !!!" >> $log_dir/tools_error.log
            echo "***********************************crosswalk-apks-$1-$2/XWalkRuntimeLib.apk not exist !!!***********************************"
            exit 1
        fi

        if [ -d $pkg_tools/crosswalk-$1 ];then
            cp -a $pkg_tools/crosswalk-$1 crosswalk
        else
            echo "crosswalk-$1 not exist !!!" >> $log_dir/tools_error.log
            echo "**************************************crosswalk-$1 not exist !!!*******************************************"
            exit 1

        fi

        if [ -d $pkg_tools/crosswalk-webview-$1-$2 ];then
            cp -a $pkg_tools/crosswalk-webview-$1-$2 crosswalk-webview
        else
            echo "$pkg_tools/crosswalk-webview-$1-$2 not exist !!!" >> $log_dir/tools_error.log
            echo "*****************************************$pkg_tools/crosswalk-webview-$1-$2 not exist !!!***************************************"
            exit 1

        fi

    else
        echo "arguments error !!!"
    fi

}



sync_code(){
    # Get latest code from github
    cd $demoex_dir ; git reset --hard HEAD ; git pull ; cd -
    cd $cts_dir ; git reset --hard HEAD; git checkout $1; git pull;cd -
}


updateVersionNum(){

    sed -i "s|\"main-version\": \"\([^\"]*\)\"|\"main-version\": \"$1\"|g" $cts_dir/VERSION
    #find $WW_dir -type f -delete
}


merge_xml(){
    if [ $1 = "usecase-webapi-xwalk-tests" ] || [ $1 = "webapi-usecase-tests" ];then

        echo "process usecase-webapi-xwalk-tests start..."
        cp -dpRv $demoex_dir/samples/* $2/samples/
        sed -i -e '/<\/suite/d ;/<\/test_definition/d' $2/tests.android.xml && sed -n '1,/<set name\=\"Third Party Framework/p' $demoex_dir/tests.android.xml | sed '$d' | sed -n '/<set/,$p' >> $2/tests.android.xml && tail -n2 $demoex_dir/tests.android.xml >> $2/tests.android.xml
        sed -i -e '/<\/suite/d ;/<\/test_definition/d' $2/tests.tizen.xml && sed -n '/<set/,$p' $demoex_dir/tests.tizen.xml >> $2/tests.tizen.xml

    elif [ $1 = "usecase-wrt-android-tests" ] || [ $1 = "wrt-usecase-android-tests" ];then

        echo "process usecase-wrt-android-tests start..."
        cp -dpRv $demoex_dir/samples-wrt/* $2/tests/
        sed -i -e '/<\/suite/d ;/<\/test_definition/d' $2/tests.android.xml && sed -n '/<set name\=\"Third Party Framework/,${/<!--/,/-->/d;p}' $demoex_dir/tests.android.xml >> $2/tests.android.xml
    elif [ $1 = "usecase-cordova-android-tests" ];then
        echo "process usecase-cordova-android-tests..."
        cp -dpRv $demoex_dir/samples-cordova/* $2/tests/
        sed -i -e '/<\/suite>/d;/<\/test_definition>/d' $2/tests.xml && sed -n '/<set name="Cordova">/,${/-->/d;p}' $demoex_dir/tests.android.xml >> $2/tests.xml

    fi

}

cancel_xml(){

    if [ $1 = "usecase-webapi-xwalk-tests" ] || [ $1 = "webapi-usecase-tests" ];then
        sample_list=`ls $demoex_dir/samples/`
        cd $2/samples
        #cd samples
        rm -rf $sample_list
        git checkout .
        cd -

        cd $2
        rm -f tests.android.xml tests.tizen.xml
        git checkout tests.android.xml
        git checkout tests.tizen.xml
        cd -
    elif [ $1 = "usecase-wrt-android-tests" ] || [ $1 = "wrt-usecase-android-tests" ];then
        sample_list=`ls $demoex_dir/samples-wrt/`
        cd $2/tests/
        rm -rf $sample_list
        git checkout .
        cd -

        cd $2
        rm -f tests.android.xml
        git checkout tests.android.xml
        cd -
    elif [ $1 = "usecase-cordova-android-tests" ];then
        sample_list=`ls $demoex_dir/samples-cordova/`
        cd $2/tests/
        rm -rf $sample_list
        git checkout .
        cd -

        cd $2
        rm -f tests.xml
        git checkout tests.xml
        cd -
    fi
}



pack_embeddingapi11()
{
    prepare_tools $1 $2
    #cd $cts_dir
    #branch_num=`git branch | awk '$1=="*"{print $2}' | awk -F"-" '{print $2}'`
    pkg_pvum=`get_vnum $1 $cts_dir $4`
    for emb_pkg in $EMBEDDINGLIST;do
        num=`find $cts_dir -name $emb_pkg -type d |wc -l`
        if [ $num -eq 1 ];then
            emb_pkg_dir=`find $cts_dir -name $emb_pkg -type d`
            if [[ $4 == 's' ]];then
                find $cts_dir/tools/crosswalk-webview/ -name "libxwalkcore.so" -exec rm -f {} \;
                find $cts_dir/tools/crosswalk-webview/ -name "xwalk_core_library_java_library_part.jar" -exec rm -f {} \;
                emshdir=$WW_dir/shared_mode/$3/$2
            else
                emshdir=$WW_dir/embedded_mode/$2
            fi
            if [ $emb_pkg = "embedding-api-android-tests" ];then
                #end_flags="v1 v2 v3 v4"
                #for emd_flag in $end_flags;do
                    emd_flag=$5
                    $cts_dir/tools/build/pack.py -t embeddingapi --cv $emd_flag -s $emb_pkg_dir -d $emshdir --tools=$cts_dir/tools
                    if [ $? -ne 0 ];then
                        echo "$emb_pkg failed">>$script_dir/logs/canary_error.log
                    else
                        emb_pkgname=`ls $emshdir | grep "embedding-api-android"`
                        #mv $emshdir/$emb_pkgname $emshdir/${emb_pkgname/api-android/api-$emd_flag-android}
                        #mv $emshdir/$emb_pkgname $emshdir/embedding-api-android-tests-$pkg_pvum-1.embeddingapi.zip
                        mv $emshdir/$emb_pkgname $emshdir/${emb_pkgname/$1/$pkg_pvum}
                    fi
                #done
            else
                $cts_dir/tools/build/pack.py -t embeddingapi -s $emb_pkg_dir -d $WW_dir/android/embeddingapi/$2 --tools=$cts_dir/tools
                if [ $? -ne 0 ];then
                    echo "$emb_pkg failed">>$script_dir/logs/canary_error.log
                else
                    mv $emshdir/$emb_pkg-$1-1.embeddingapi.zip $emshdir/$emb_pkg-$pkg_pvum-1.embeddingapi.zip
                fi

            fi
            echo $emb_pkg_dir
        else
            echo "$emb_pkg Not unique"    
        fi
    done
}

pack_embeddingapi10()
{
    prepare_tools $1 $2
    pkg_pvum=`get_vnum $1 $cts_dir $4`
    for emb_pkg in $EMBEDDINGLIST;do
        num=`find $cts_dir -name $emb_pkg -type d |wc -l`
        if [ $num -eq 1 ];then
            emb_pkg_dir=`find $cts_dir -name $emb_pkg -type d`
            if [[ $4 == 's' ]];then
                find $cts_dir/tools/crosswalk-webview/ -name "libxwalkcore.so" -exec rm -f {} \;
                find $cts_dir/tools/crosswalk-webview/ -name "xwalk_core_library_java_library_part.jar" -exec rm -f {} \;
                emshdir=$WW_dir/shared_mode/$3/$2
            else
                emshdir=$WW_dir/embedded_mode/$2
            fi
            $cts_dir/tools/build/pack.py -t embeddingapi -s $emb_pkg_dir -d $emshdir --tools=$cts_dir/tools
            if [ $? -ne 0 ];then
                echo "$emb_pkg failed">>$script_dir/logs/beta10_error.log
            else
                mv $emshdir/$emb_pkg-$1-1.embeddingapi.zip $emshdir/$emb_pkg-$pkg_pvum-1.embeddingapi.zip
            fi
            echo $emb_pkg_dir
        else
            echo "$emb_pkg Not unique"    
        fi
    done
}


pack_embeddingapi9()
{
    prepare_tools $1 $2
    pkg_pvum=`get_vnum $1 $cts_dir $4`
    for emb_pkg in $EMBEDDINGLIST;do
        num=`find $cts_dir -name $emb_pkg -type d |wc -l`
        if [ $num -eq 1 ];then

            emb_pkg_dir=`find $cts_dir -name $emb_pkg -type d`
            if [[ $4 == 's' ]];then
                find $cts_dir/tools/crosswalk-webview/ -name "libxwalkcore.so" -exec rm -f {} \;
                find $cts_dir/tools/crosswalk-webview/ -name "xwalk_core_library_java_library_part.jar" -exec rm -f {} \;
                emshdir=$WW_dir/shared_mode/$3/$2
            else
                emshdir=$WW_dir/embedded_mode/$2
            fi
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
            $cts_dir/tools/build/pack.py -t embeddingapi -s $emb_pkg_dir -d $emshdir --tools=$cts_dir/tools
            if [ $? -ne 0 ];then
                echo "$emb_pkg failed">>$script_dir/logs/beta9_error.log
            else
                mv $emshdir/$emb_pkg-$1-1.embeddingapi.zip $emshdir/$emb_pkg-$pkg_pvum-1.embeddingapi.zip
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

pack_apk()
{
    prepare_tools $1 $2
    pkg_pvum=`get_vnum $1 $cts_dir $4`
    for apk in $APKLIST;do
        num=`find $cts_dir -name $apk -type d |wc -l`
        if [[ $4 == 's' ]];then
            emshdir=$WW_dir/shared_mode/$3/$2
            pkg_mode='shared'
        else
            emshdir=$WW_dir/embedded_mode/$2
            pkg_mode='embedded'
        fi
        if [ $num -eq 1 ];then
            apk_dir=`find $cts_dir -name $apk -type d`
            cancel_xml $apk $apk_dir
            merge_xml $apk $apk_dir
            $cts_dir/tools/build/pack.py -t apk -m $pkg_mode -a $2 -s $apk_dir -d $emshdir --tools=$cts_dir/tools
            if [ $? -ne 0 ];then
                echo "[apk][$2] <$apk> failed">>$script_dir/logs/canary_error.log
            else
                mv $emshdir/$apk-$1-1.apk.zip $emshdir/$apk-$pkg_pvum-1.apk.zip
            fi
            cancel_xml $apk $apk_dir
            echo $apk_dir
        else
            echo "$apk Not unique"    
        fi
    done
}



pack_aio()
{
    prepare_tools $1 $2
    pkg_pvum=`get_vnum $1 $cts_dir $4`
    for aio in $AIOLIST;do
        num=`find $cts_dir -name $aio -type d |wc -l`
        if [[ $4 == 's' ]];then
            emshdir=$WW_dir/shared_mode/$3/$2
            pkg_mode='shared'
        else
            emshdir=$WW_dir/embedded_mode/$2
            pkg_mode='embedded'
        fi
        
        if [ $num -eq 1 ];then
            aio_dir=`find $cts_dir -name $aio -type d`
            cd $aio_dir
            ./pack.sh -a $2 -m $pkg_mode
            if [ $? -ne 0 ];then
                echo "[webapi all-in-one][$2][$pkg_mode] <$aio_$2> failed">>$script_dir/logs/canary_error.log
            fi
            mv $aio-$1-1.apk.zip $aio-$pkg_pvum-1.apk.zip
            mv $aio-$pkg_pvum-1.apk.zip $emshdir
            cd -
        else
            echo "$aio_$2 Not unique"    
        fi
    done
}


branch_pack(){

    if [[ $1 == "master" ]];then
        cts_dir=$script_dir/../work_space/release/crosswalk-test-suite
        #version_num=`cat $flag_dir/Canary_New_Number`
        beta11_num=`cat $flag_dir/Beta11_Number`;beta10_num=`cat $flag_dir/Beta10_Number`;beta9_num=`cat $flag_dir/Beta9_Number`
        source $script_dir/list_suites/canary_com_list
        prepare_env
        sync_code $1
        updateVersionNum $beta11_num
        #pack_apk $version_num x86 $1 s
        #pack_apk $version_num arm $1 s
        #pack_aio $version_num x86 s
        #pack_aio $version_num arm s
        pack_embeddingapi11 $beta11_num x86 $1 s v4
        pack_embeddingapi11 $beta11_num arm $1 s v4
        
        cts_dir=$script_dir/../work_space/release/beta-crosswalk-test-suite
        prepare_env
        sync_code $1
        updateVersionNum $beta10_num
        pack_embeddingapi11 $beta10_num x86 $1 s v3
        pack_embeddingapi11 $beta10_num arm $1 s v3
        updateVersionNum $beta9_num
        pack_embeddingapi11 $beta9_num x86 $1 s v1
        pack_embeddingapi11 $beta9_num arm $1 s v1
        pack_embeddingapi11 $beta9_num x86 $1 s v2
        pack_embeddingapi11 $beta9_num arm $1 s v2
        vvnum=`echo $version_num | awk -F'.' '{print $1}'`
        if [ $bnum -eq $vvnum ];then
            pack_aio $version_num x86 $1 s
            pack_aio $version_num arm $1 s
            #pack_embeddingapi11 $version_num x86 $1 e
            #pack_embeddingapi11 $version_num x86 $1 e
        fi
    
    elif [[ $1 == "Crosswalk-11" ]];then
        bnum=`echo $1 | awk -F'-' '{print $2}'`
        cts_dir=$script_dir/../work_space/release/beta-crosswalk-test-suite
        version_list=`cat $flag_dir/Beta11_Number $flag_dir/Canary_New_Number`
        source $script_dir/list_suites/beta11_com_list
        prepare_env
        for version_num in $version_list;do
            sync_code $1
            updateVersionNum $version_num
            pack_apk $version_num x86 $1 s
            pack_apk $version_num arm $1 s
            #pack_embeddingapi11 $version_num x86 $1 s
            #pack_embeddingapi11 $version_num arm $1 s
            vvnum=`echo $version_num | awk -F'.' '{print $1}'`
            if [ $bnum -eq $vvnum ];then
                pack_aio $version_num x86 $1 s
                pack_aio $version_num arm $1 s
                pack_embeddingapi11 $version_num x86 $1 e
                pack_embeddingapi11 $version_num x86 $1 e
            fi
          
        done
       
    elif [[ $1 == "Crosswalk-10" ]];then
        bnum=`echo $1 | awk -F'-' '{print $2}'`
        cts_dir=$script_dir/../work_space/release/beta-crosswalk-test-suite
        version_list=`cat $flag_dir/Beta10_Number $flag_dir/Canary_New_Number`
        source $script_dir/list_suites/beta10_com_list
        prepare_env
        for version_num in $version_list;do
            sync_code $1
            updateVersionNum $version_num
            pack_apk $version_num x86 $1 s
            pack_apk $version_num arm $1 s
            #pack_embeddingapi10 $version_num x86 $1 s
            #pack_embeddingapi10 $version_num arm $1 s
            vvnum=`echo $version_num | awk -F'.' '{print $1}'`
            if [ $bnum -eq $vvnum ];then
                pack_embeddingapi10 $version_num x86 $1 e
                pack_embeddingapi10 $version_num x86 $1 e
            fi
        done

    elif [[ $1 == "Crosswalk-9" ]];then
        bnum=`echo $1 | awk -F'-' '{print $2}'`
        cts_dir=$script_dir/../work_space/release/beta-crosswalk-test-suite
        version_list=`cat $flag_dir/Beta9_Number $flag_dir/Canary_New_Number`
        source $script_dir/list_suites/beta9_com_list
        prepare_env
        for version_num in $version_list;do
            sync_code $1
            updateVersionNum $version_num
            pack_apk $version_num x86 $1 s
            pack_apk $version_num arm $1 s
            #pack_embeddingapi9 $version_num x86 $1 s
            #pack_embeddingapi9 $version_num arm $1 s
            vvnum=`echo $version_num | awk -F'.' '{print $1}'`
            if [ $bnum -eq $vvnum ];then
                pack_embeddingapi9 $version_num x86 $1 e
                pack_embeddingapi9 $version_num x86 $1 e
            fi
        done
    fi

}

branch_pack master
