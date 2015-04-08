#!/bin/bash

PATH=/usr/java/sdk/tools:/usr/java/sdk/platform-tools:/usr/java/jdk1.7.0_67/bin:/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/games:/usr/local/games:/usr/share/apache-maven/bin

ROOT_DIR=$(dirname $(readlink -f $0))
SHARED_SPACE_DIR=/mnt/jiajiax_shared/release
CTS_DIR=$ROOT_DIR/../work_space/release/crosswalk-cordova4.0
DEMOEX_DIR=$CTS_DIR/../demo-express
LOG_DIR=$ROOT_DIR/logs
RELEASE_COMMIT_FILE=$LOG_DIR/$(date +%Y-%m-%d-%T)_release
VERSION_FLAG=$ROOT_DIR/version_flag/Beta13_Number
VERSION_NO=$(cat $VERSION_FLAG)
BUILD_LOG=$LOG_DIR/beta_error_${VERSION_NO}.log
PKG_TOOLS=$CTS_DIR/../pkg_tools/
SAMPLE_LIST=""
wweek=$(date +"%W" -d "+1 weeks")
WW_DIR=/data/TestSuites_Storage/live
. $ROOT_DIR/list_suites/beta13_list

#echo "Cordova4.0 Begin flag ---------------- `date` ---------------" >> $BUILD_LOG

CORDOVA_SAMPLEAPP_LIST="helloworld
remotedebugging
gallery"


NEW_VERSION_FLAG=0
SUITE_DIR=""
declare -A tests_path_arr
EMBEDDED_TESTS_DIR=""
SHARED_TESTS_DIR=""
CORDOVA_TESTS_DIR=""
TIZEN_TESTS_DIR=""
ANDROID_IN_PROCESS_FLAG=""
TIZEN_IN_PROCESS_FLAG=""
RELEASE_COMMIT_ID=""
BRANCH_NAME=Crosswalk-13

#while true;do
#    build_flag=$(ls -al $VERSION_FLAG | awk '{print $7}')
#    date_now=`date +%d`
#    if [ $build_flag -eq $date_now ] ;then
#        echo "Release Begin..."
#        break
#    else
#        hour_now=`date +%H`
#        if [ $hour_now -ge 5 ];then
#            echo "STILL $VERSION_NO, NO UPDATE !!!" >> $BUILD_LOG
#            exit 1
#        fi
#        sleep 10m 
#    
#    fi  
#done

init_ww(){
    
    [ -d $1/android/beta/$VERSION_NO/testsuites-cordova4.0 ] && rm -rf $1/android/beta/$VERSION_NO/testsuites-cordova4.0
    mkdir -p $1/android/beta/$VERSION_NO/testsuites-cordova4.0/{x86,arm}
    
    EMBEDDED_TESTS_DIR=$1/android/beta/$VERSION_NO/testsuites-embedded/
    SHARED_TESTS_DIR=$1/android/beta/$VERSION_NO/testsuites-shared/
    CORDOVA_TESTS_DIR=$1/android/beta/$VERSION_NO/testsuites-cordova4.0/
    ANDROID_IN_PROCESS_FLAG=$1/android/beta/$VERSION_NO/BUILD-INPROCESS
    [ ! -f $ANDROID_IN_PROCESS_FLAG ] && touch $ANDROID_IN_PROCESS_FLAG
    tests_path_arr=([embedded]=$EMBEDDED_TESTS_DIR [shared]=$SHARED_TESTS_DIR)

}


prepare_tools(){
    cd $CTS_DIR/tools
    if [ $# -eq 2 ];then
        if [[ $2 == "apk" ]];then
            if [ -f $PKG_TOOLS/crosswalk-apks-$VERSION_NO-$1/XWalkRuntimeLib.apk ];then
                rm -rf XWalkRuntimeLib.apk
                cp $PKG_TOOLS/crosswalk-apks-$VERSION_NO-$1/XWalkRuntimeLib.apk . 
            else
                echo "[tools] crosswalk-apks-$VERSION_NO-$1/XWalkRuntimeLib.apk not exist !!!" >> $BUILD_LOG
                return 1
            fi

            if [ -d $PKG_TOOLS/crosswalk-$VERSION_NO ];then
                rm -rf crosswalk
                cp -a $PKG_TOOLS/crosswalk-$VERSION_NO crosswalk
            else
                echo "[tools] crosswalk-$VERSION_NO not exist !!!" >> $BUILD_LOG
                return 1

            fi
        fi

        if [[ $2 == "cordova" ]];then
            if [ -d $PKG_TOOLS/crosswalk-cordova-$VERSION_NO-$1 ];then
                rm -rf cordova
                cp -a $PKG_TOOLS/crosswalk-cordova-$VERSION_NO-$1 cordova
            else
                echo "[tools] crosswalk-cordova-$VERSION_NO-$1 not exist !!!" >> $BUILD_LOG
                return 1

            fi
        fi

        if [[ $2 == "embeddingapi" ]];then
            if [ -d $PKG_TOOLS/crosswalk-webview-$VERSION_NO-$1 ];then
                rm -rf crosswalk-webview
                cp -a $PKG_TOOLS/crosswalk-webview-$VERSION_NO-$1 crosswalk-webview
            else
                echo "[tools] $PKG_TOOLS/crosswalk-webview-$VERSION_NO-$1 not exist !!!" >> $BUILD_LOG
                return 1

            fi
        fi

    else
        echo "arguments error !!!"
    fi

}

sync_Code(){
    # Get latest code from github
    cd $DEMOEX_DIR ; git reset --hard HEAD ;git checkout master ;git pull ;cd -
    #cd $CTS_DIR ; git reset --hard HEAD; git checkout master; cd -
    cd $CTS_DIR ; git reset --hard HEAD;git checkout $BRANCH_NAME ;git pull ;git stash apply stash@{0}
    cd $CTS_DIR/tools/cordova ; git reset --hard HEAD;git checkout master ;git pull ;git stash apply stash@{0}
    cd $CTS_DIR/tools/cordova_plugins/cordova-crosswalk-engine;git reset --hard HEAD;git checkout master;git pull
    cd $CTS_DIR/tools/cordova_plugins/cordova-plugin-whitelist;git pull
    
}


updateVersionNum(){

    sed -i "s|\"main-version\": \"\([^\"]*\)\"|\"main-version\": \"$VERSION_NO\"|g" $CTS_DIR/VERSION
    sed -i "s/:11+/:$VERSION_NO/g" $CTS_DIR/tools/cordova_plugins/cordova-crosswalk-engine/libs/xwalk_core_library/xwalk.gradle
}



merge_Tests(){
    if [ $1 = "usecase-webapi-xwalk-tests" ];then

        echo "process usecase-webapi-xwalk-tests start..."
        cp -dpRv $DEMOEX_DIR/samples/* $2/samples/
        cp -dpRv $DEMOEX_DIR/res/* $2/res/

    elif [ $1 = "usecase-wrt-android-tests" ];then

        echo "process usecase-wrt-android-tests start..."
        cp -dpRv $DEMOEX_DIR/samples-wrt/* $2/samples/
    elif [ $1 = "usecase-cordova-android-tests" ];then
        echo "process usecase-cordova-android-tests..."
        cp -dpRv $DEMOEX_DIR/samples-cordova/* $2/samples/

    fi

}

recover_Tests(){

    if [ $1 = "usecase-webapi-xwalk-tests" ];then
        SAMPLE_LIST=`ls $DEMOEX_DIR/samples/`
        cd $2/samples/
        #cd samples
        rm -rf $SAMPLE_LIST
        git checkout .
        cd -

        cd $2/res/
        git clean -dfx .
        git checkout .
        cd -
    elif [ $1 = "usecase-wrt-android-tests" ];then
        SAMPLE_LIST=`ls $DEMOEX_DIR/samples-wrt/`
        cd $2/samples/
        rm -rf $SAMPLE_LIST
        git checkout .
        cd -
    elif [ $1 = "usecase-cordova-android-tests" ];then
        SAMPLE_LIST=`ls $DEMOEX_DIR/samples-cordova/`
        cd $2/samples/
        rm -rf $SAMPLE_LIST
        git checkout .
        cd -
    fi
}

multi_thread_pack(){
    trap "exec 113>&-;exec 113<&-;exit 0" 2

    mkfifo $CTS_DIR/operator_tmp
    exec 113<>$CTS_DIR/operator_tmp
    
    for ((i=1;i<=$1;i++));do
        echo -ne "\n" 1>&113
    done

}

clean_operator(){

    
    rm -f $CTS_DIR/operator_tmp
    exec 113>$-
    exec 113<$-

}


pack_Cordova(){
    #prepare_tools $1 cordova
    #if [ $? -eq 0 ];then
        #clean_operator
        #multi_thread_pack 5
        for cordova in $CORDOVALIST;do
            read -u 113
            {
                [ $cordova = "usecase-webapi-xwalk-tests" ] && sed -i '33i\    <uses-permission android:name="android.permission.CAMERA" />' $CTS_DIR/tools/cordova/bin/templates/project/AndroidManifest.xml
                cordova_num=`find $CTS_DIR -name $cordova -type d | wc -l`
                if [ $cordova_num -eq 1 ];then
                    cordova_dir=`find $CTS_DIR -name $cordova -type d`
                    $CTS_DIR/tools/build/pack.py -t cordova --sub-version 4.0 -s $cordova_dir -d $CORDOVA_TESTS_DIR/$1 --tools=$CTS_DIR/tools
                    [ $? -ne 0 ] && echo "[cordova] [$1] <$cordova>" >> $BUILD_LOG
                elif [ $cordova_num -gt 1 ];then
                    echo "$cordova not unique !!!" >> $BUILD_LOG
                else
                    echo "$cordova not exists !!!" >> $BUILD_LOG
                fi
                [ $cordova = "usecase-webapi-xwalk-tests" ] && sed -i '33d' $CTS_DIR/tools/cordova/bin/templates/project/AndroidManifest.xml
                echo -ne "\n" 1>&113
            }&
        done

        wait
        #clean_operator
    #fi
}

pack_Cordova_SampleApp(){
    #prepare_tools $1 cordova
    #if [ $? -eq 0 ];then
        cd $CTS_DIR/tools/build/
        rm -f *.apk
        rm -f *.zip
        #clean_operator
        #multi_thread_pack 4
        for cordova_sampleapp in $CORDOVA_SAMPLEAPP_LIST;do
            read -u 113
            {
                ./pack_cordova_sample.py -n $cordova_sampleapp --cordova-version 4.0 --tools=$CTS_DIR/tools
                [ $? -ne 0 ] && echo "[cordova_sampleapp] [$1] $cordova_sampleapp" >> $BUILD_LOG
                echo -ne "\n" 1>&113
            }&
        done

        wait
        #clean_operator
        zip cordova3.6_sampleapp_${1}.zip *.apk && cp cordova3.6_sampleapp_${1}.zip $CORDOVA_TESTS_DIR/$1
        rm -f *.apk
        rm -f *.zip
        
    #fi

}


pack_Aio(){
    #prepare_tools $2 $1
    #if [ $? -eq 0 ];then
        #clean_operator
        #multi_thread_pack 3
        for aio in $AIOLIST;do
            read -u 113
            {
                aio_num=`find $CTS_DIR -name $aio -type d | wc -l`
                if [ $aio_num -eq 1 ];then
                    aio_dir=`find $CTS_DIR -name $aio -type d`
                    cd $aio_dir
                    rm -f *.zip
                    if [ $1 = "apk" ];then
                        ./pack.sh -a $2 -m $3
                        [ $? -ne 0 ] && echo "[aio] [$1] [$2] [$3] <$aio>" >> $BUILD_LOG
                        mv ${aio}-${VERSION_NO}-1.apk.zip ${tests_path_arr[$3]}/$2
                    elif [ $1 = "cordova" ];then
                        ./pack.sh -t cordova
                        [ $? -ne 0 ] && echo "[aio] [$1] [$2] <$aio>" >> $BUILD_LOG
                        mv ${aio}-${VERSION_NO}-1.cordova.zip $CORDOVA_TESTS_DIR/$2
                    fi
                elif [ $aio_num -gt 1 ];then
                    echo "$aio not unique !!!" >> $BUILD_LOG
                else
                    echo "$aio not exists !!!" >> $BUILD_LOG
                fi
                echo -ne "\n" 1>&113
            }&
        done

        wait
        #clean_operator
    #fi    


}


save_Package(){
    mail_pkg_address=android/beta/$VERSION_NO
    python $ROOT_DIR/smail.py $VERSION_NO $mail_pkg_address $RELEASE_COMMIT_ID $BRANCH_NAME nightly
        
    wtoday=$[$(date +%w)]
    wdir="WW"$wweek
    complete_time=`date +%m-%d-%H%M`

    mkdir -p /mnt/otcqa/$wdir/{master/"ww"$wweek"."$wtoday,beta/"ww"$wweek"."$wtoday,stable,webtestingservice}
    fulltest_dir=/mnt/otcqa/$wdir/beta/"ww"$wweek"."$wtoday/$VERSION_NO"~"$complete_time
    mkdir -p $fulltest_dir
    cp -r $EMBEDDED_TESTS_DIR $fulltest_dir/
    cp -r $CORDOVA_TESTS_DIR'*' $fulltest_dir/
    chmod -R 777 $fulltest_dir
    mail_pkg_address=$wdir/beta/"ww"$wweek"."$wtoday/$VERSION_NO"~"$complete_time
    python $ROOT_DIR/smail.py $VERSION_NO $mail_pkg_address $RELEASE_COMMIT_ID $BRANCH_NAME DL

}



init_ww $WW_DIR
sync_Code
updateVersionNum

recover_Tests usecase-webapi-xwalk-tests $CTS_DIR/usecase/usecase-webapi-xwalk-tests
recover_Tests usecase-wrt-android-tests $CTS_DIR/usecase/usecase-wrt-android-tests
recover_Tests usecase-cordova-android-tests $CTS_DIR/usecase/usecase-cordova-android-tests

merge_Tests usecase-webapi-xwalk-tests $CTS_DIR/usecase/usecase-webapi-xwalk-tests
merge_Tests usecase-wrt-android-tests $CTS_DIR/usecase/usecase-wrt-android-tests
merge_Tests usecase-cordova-android-tests $CTS_DIR/usecase/usecase-cordova-android-tests

clean_operator
multi_thread_pack 8



#pack_Cordova x86 &
#pack_Aio cordova x86 &
#pack_Cordova_SampleApp x86 &
#wait

pack_Cordova arm &
pack_Aio cordova arm &
pack_Cordova_SampleApp arm &
wait


clean_operator

rm -f $ANDROID_IN_PROCESS_FLAG
echo "End flag ---------------- `date`------------------" >> $BUILD_LOG

save_Package


recover_Tests usecase-webapi-xwalk-tests $CTS_DIR/usecase/usecase-webapi-xwalk-tests
recover_Tests usecase-wrt-android-tests $CTS_DIR/usecase/usecase-wrt-android-tests
recover_Tests usecase-cordova-android-tests $CTS_DIR/usecase/usecase-cordova-android-tests

