#!/bin/bash

PATH=/usr/java/sdk/tools:/usr/java/sdk/platform-tools:/usr/java/jdk1.7.0_67/bin:/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/games:/usr/local/games:/usr/share/apache-maven/bin

ROOT_DIR=$(dirname $(readlink -f $0))
SHARED_SPACE_DIR=/mnt/jiajiax_shared/release
CTS_DIR=$ROOT_DIR/../work_space/release/crosswalk-test-suite
DEMOEX_DIR=$CTS_DIR/../demo-express
LOG_DIR=$ROOT_DIR/logs
RELEASE_COMMIT_FILE=$LOG_DIR/$(date +%Y-%m-%d-%T)_release
VERSION_FLAG=$ROOT_DIR/version_flag/Canary_New_Number
VERSION_NO=$(cat $VERSION_FLAG)
BUILD_LOG=$LOG_DIR/canary_error_${VERSION_NO}.log
PKG_TOOLS=$CTS_DIR/../pkg_tools/
SAMPLE_LIST=""
wweek=$(date +"%W" -d "+1 weeks")
WW_DIR=/data/TestSuites_Storage/live
. $ROOT_DIR/list_suites/release_list

echo "Begin flag ---------------- `date` ---------------" > $BUILD_LOG

CORDOVA_SAMPLEAPP_LIST="mobilespec
helloworld
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
    
    [ -d $1/android/master/$VERSION_NO ] && rm -rf $1/android/master/$VERSION_NO
    if [ $(date +%w) -eq 3 ];then
        [ -d $1/tizen-common/master/$VERSION_NO ] && rm -rf $1/tizen-common/master/$VERSION_NO
        mkdir -p $1/{android/{master/$VERSION_NO/{testsuites-embedded/{x86,arm},testsuites-shared/{x86,arm},testsuites-cordova/{x86,arm}},beta},tizen-common/master/$VERSION_NO}
        TIZEN_TESTS_DIR=$1/tizen-common/master/$VERSION_NO
        TIZEN_IN_PROCESS_FLAG=$TIZEN_TESTS_DIR/BUILD-INPROCESS
        [ ! -f $TIZEN_IN_PROCESS_FLAG ] && touch $TIZEN_IN_PROCESS_FLAG
    else
        mkdir -p $1/android/{master/$VERSION_NO/{testsuites-embedded/{x86,arm},testsuites-shared/{x86,arm},testsuites-cordova/{x86,arm}},beta}
    fi
    
    EMBEDDED_TESTS_DIR=$1/android/master/$VERSION_NO/testsuites-embedded/
    SHARED_TESTS_DIR=$1/android/master/$VERSION_NO/testsuites-shared/
    CORDOVA_TESTS_DIR=$1/android/master/$VERSION_NO/testsuites-cordova/
    ANDROID_IN_PROCESS_FLAG=$1/android/master/$VERSION_NO/BUILD-INPROCESS
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
    if [ $(date +%w) -eq 3 ];then
        cd $CTS_DIR
        git reset --hard HEAD
        git checkout master
        git pull
        echo "---------- Release Commit -------">>$RELEASE_COMMIT_FILE
        git log -1 --name-status >>$RELEASE_COMMIT_FILE
        echo "---------------------------------">>$RELEASE_COMMIT_FILE
        RELEASE_COMMIT_ID=$(git log -1 --pretty=oneline | awk '{print $1}')
        echo $RELEASE_COMMIT_ID > $SHARED_SPACE_DIR/Release_ID
        cd -
        cat $RELEASE_COMMIT_FILE | mutt -s "$wweek Week Release Commit" jiajiax.li@intel.com
    else
        RELEASE_COMMIT_ID=`cat $SHARED_SPACE_DIR/Release_ID`
        cd $CTS_DIR ; git reset --hard HEAD;git checkout master;git pull ;git reset --hard $RELEASE_COMMIT_ID;cd -
    fi
}


updateVersionNum(){

    sed -i "s|\"main-version\": \"\([^\"]*\)\"|\"main-version\": \"$VERSION_NO\"|g" $CTS_DIR/VERSION
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
    trap "exec 100>&-;exec 100<&-;exit 0" 2

    mkfifo $CTS_DIR/operator_tmp
    exec 100<>$CTS_DIR/operator_tmp
    
    for ((i=1;i<=$1;i++));do
        echo -ne "\n" 1>&100
    done

}

clean_operator(){

    
    rm -f $CTS_DIR/operator_tmp
    exec 100>$-
    exec 100<$-

}

check_Suite(){
    sum_suites=`find $CTS_DIR -name $1 -type d |wc -l`
    if [ $sum_suites -eq 1 ];then
        SUITE_DIR=`find $CTS_DIR -name $1 -type d`
        echo $SUITE_DIR
        return
    elif [ $sum_suites -gt 1 ];then
        echo "$1 not unique !!!" >> $BUILD_LOG
        return 1
    else
        echo "$1 not exists !!!" >> $BUILD_LOG
        return 1
    fi
}


pack_Wgt(){
    #clean_operator
    #multi_thread_pack 10
    for wgt in $WGTLIST;do
        read -u 100
        {
            wgt_num=`find $CTS_DIR -name $wgt -type d | wc -l`
            if [ $wgt_num -eq 1 ];then
                wgt_dir=`find $CTS_DIR -name $wgt -type d`
                $CTS_DIR/tools/build/pack.py -t wgt -s $wgt_dir -d $TIZEN_TESTS_DIR --tools=$CTS_DIR/tools
                [ $? -ne 0 ] && echo "[wgt] <$wgt>" >> $BUILD_LOG
            elif [ $wgt_num -gt 1 ];then
                echo "$1 not unique !!!" >> $BUILD_LOG
            else
                echo "$1 not exists !!!" >> $BUILD_LOG
            fi
             echo -ne "\n" 1>&100
        }&
    done
    wait
    #clean_operator
}

pack_Xpk(){
    for xpk in $XPKLIST;do
        xpk_num=`find $CTS_DIR -name $xpk -type d | wc -l`
        if [ $xpk_num -eq 1 ];then
        #check_Suite $xpk
            xpk_dir=`find $CTS_DIR -name $xpk -type d`
            #recover_Tests $xpk $SUITE_DIR
            #merge_Tests $xpk $SUITE_DIR
            $CTS_DIR/tools/build/pack.py -t xpk -s $xpk_dir -d $TIZEN_TESTS_DIR --tools=$CTS_DIR/tools
            [ $? -ne 0 ] && echo "[xpk] <$xpk>" >> $BUILD_LOG
            #recover_Tests $xpk $SUITE_DIR
        elif [ $xpk_num -gt 1 ];then
            echo "$xpk not unique !!!" >> $BUILD_LOG
        else
            echo "$xpk not exists !!!" >> $BUILD_LOG
        fi
    done
}

pack_Apk(){

    #prepare_tools $1 apk
    #if [ $? -eq 0 ];then
        
        #clean_operator
        #multi_thread_pack 5
        for apk in $APKLIST;do
            read -u 100
            {
                apk_num=`find $CTS_DIR -name $apk -type d | wc -l`
                if [ $apk_num -eq 1 ];then
                    apk_dir=`find $CTS_DIR -name $apk -type d`
                    $CTS_DIR/tools/build/pack.py -t apk -m $2 -a $1 -s $apk_dir -d ${tests_path_arr[$2]}/$1 --tools=$CTS_DIR/tools
                    [ $? -ne 0 ] && echo "[apk] [$1] [$2] <$apk>" >> $BUILD_LOG
                elif [ $apk_num -gt 1 ];then
                    echo "$apk not unique !!!" >> $BUILD_LOG
                else
                    echo "$apk not exists !!!" >> $BUILD_LOG
                fi

                echo -ne "\n" 1>&100
            }&
        done

        wait
        #clean_operator
    #fi

}


pack_Cordova(){
    #prepare_tools $1 cordova
    #if [ $? -eq 0 ];then
        #clean_operator
        #multi_thread_pack 5
        for cordova in $CORDOVALIST;do
            read -u 100
            {
                [ $cordova = "usecase-webapi-xwalk-tests" ] && sed -i '33i\    <uses-permission android:name="android.permission.CAMERA" />' $CTS_DIR/tools/cordova/bin/templates/project/AndroidManifest.xml
                cordova_num=`find $CTS_DIR -name $cordova -type d | wc -l`
                if [ $cordova_num -eq 1 ];then
                    cordova_dir=`find $CTS_DIR -name $cordova -type d`
                    $CTS_DIR/tools/build/pack.py -t cordova -s $cordova_dir -d $CORDOVA_TESTS_DIR/$1 --tools=$CTS_DIR/tools
                    [ $? -ne 0 ] && echo "[cordova] [$1] <$cordova>" >> $BUILD_LOG
                elif [ $cordova_num -gt 1 ];then
                    echo "$cordova not unique !!!" >> $BUILD_LOG
                else
                    echo "$cordova not exists !!!" >> $BUILD_LOG
                fi
                [ $cordova = "usecase-webapi-xwalk-tests" ] && sed -i '33d' $CTS_DIR/tools/cordova/bin/templates/project/AndroidManifest.xml
                echo -ne "\n" 1>&100
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
            read -u 100
            {
                ./pack_cordova_sample.py -n $cordova_sampleapp --cordova-version 3.6 --tools=$CTS_DIR/tools
                [ $? -ne 0 ] && echo "[cordova_sampleapp] [$1] $cordova_sampleapp" >> $BUILD_LOG
                echo -ne "\n" 1>&100
            }&
        done

        wait
        #clean_operator
        zip cordova3.6_sampleapp_${1}.zip *.apk && cp cordova3.6_sampleapp_${1}.zip $CORDOVA_TESTS_DIR/$1
        rm -f *.apk
        rm -f *.zip
        
    #fi

}

pack_Embeddingapi(){
    #prepare_tools $1 embeddingapi
    #if [ $? -eq 0 ];then
        #clean_operator
        #multi_thread_pack 2
        for emb_suite in $EMBEDDINGLIST;do
            read -u 100
            {
                emb_num=`find $CTS_DIR -name $emb_suite -type d | wc -l`
                if [ $emb_num -eq 1 ];then
                    emb_dir=`find $CTS_DIR -name $emb_suite -type d`
                    if [ $2 = "shared" ];then
                        find $CTS_DIR/tools/crosswalk-webview/ -name "libxwalkcore.so" -exec rm -f {} \;
                        find $CTS_DIR/tools/crosswalk-webview/ -name "xwalk_core_library_java_library_part.jar" -exec rm -f {} \;
                        $CTS_DIR/tools/build/pack.py -t embeddingapi -s $emb_dir -d $SHARED_TESTS_DIR/$1 --tools=$CTS_DIR/tools
                    elif [ $2 = "embedded" ];then
                        $CTS_DIR/tools/build/pack.py -t embeddingapi -s $emb_dir -d $EMBEDDED_TESTS_DIR/$1 --tools=$CTS_DIR/tools
                    fi
                    [ $? -ne 0 ] && echo "[embeddingapi] [$1] [$2] <$emb_suite>" >> $BUILD_LOG
                elif [ $emb_num -gt 1 ];then
                    echo "$emb_suite not unique !!!" >> $BUILD_LOG
                else
                    echo "$emb_suite not exists !!!" >> $BUILD_LOG
                fi
                echo -ne "\n" 1>&100
            }&
        done
        
        wait
        #clean_operator
    #fi

}

pack_Aio(){
    #prepare_tools $2 $1
    #if [ $? -eq 0 ];then
        #clean_operator
        #multi_thread_pack 3
        for aio in $AIOLIST;do
            read -u 100
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
                echo -ne "\n" 1>&100
            }&
        done

        wait
        #clean_operator
    #fi    


}

copy_SDK(){

    SDK_dir=$ROOT_DIR/../images/linux-ftp.sh.intel.com/pub/mirrors/01org/crosswalk/releases/crosswalk/android/canary/$VERSION_NO
    WW_SDK_dir=$EMBEDDED_TESTS_DIR/../crosswalk-tools
    [ -d $SDK_dir ] && cp -a $SDK_dir $WW_SDK_dir
    touch $EMBEDDED_TESTS_DIR/../$RELEASE_COMMIT_ID 

}

save_Package(){
    wtoday=$[$(date +%w)]
    wdir="WW"$wweek

    mkdir -p /mnt/otcqa/$wdir/{master/"ww"$wweek"."$wtoday,beta/"ww"$wweek"."$wtoday,stable,webtestingservice}
    if [ $wtoday -eq 5 ];then
        fulltest_dir=/mnt/otcqa/$wdir/master/"ww"$wweek"."$wtoday/FullTest
        mkdir -p $fulltest_dir
        cp -r $EMBEDDED_TESTS_DIR $fulltest_dir/
        cp -r $CORDOVA_TESTS_DIR $fulltest_dir/
        chmod -R 777 $fulltest_dir
        mail_pkg_address=$wdir/master/"ww"$wweek"."$wtoday/FullTest
        python $ROOT_DIR/smail.py $VERSION_NO $mail_pkg_address $RELEASE_COMMIT_ID master
    fi    
    
}



init_ww /home/orange/myspace/kkk
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


if [ $(date +%w) -eq 3 ];then
    pack_Wgt
    pack_Xpk
    rm $TIZEN_IN_PROCESS_FLAG
fi

prepare_tools x86 embeddingapi
prepare_tools x86 apk
prepare_tools x86 cordova


pack_Cordova x86 &
pack_Apk x86 embedded &
pack_Apk x86 shared &
pack_Embeddingapi x86 embedded &
pack_Aio cordova x86 &
wait

pack_Embeddingapi x86 shared &
pack_Aio apk x86 embedded &
pack_Cordova_SampleApp x86 &
wait


prepare_tools arm embeddingapi
prepare_tools arm apk
prepare_tools arm cordova

pack_Apk arm embedded &
pack_Apk arm shared &
pack_Cordova arm &
pack_Embeddingapi arm embedded &
pack_Aio cordova arm &
wait


pack_Embeddingapi arm shared &
pack_Aio apk arm embedded &
pack_Cordova_SampleApp arm &
wait

pack_Aio apk arm shared


prepare_tools x86 apk
pack_Aio apk x86 shared

clean_operator

copy_SDK
rm -f $ANDROID_IN_PROCESS_FLAG
echo "End flag ---------------- `date`------------------" >> $BUILD_LOG

save_Package


#pack_Cordova x86 
#pack_Cordova arm 
#pack_Cordova_SampleApp x86 
#pack_Cordova_SampleApp arm 
#pack_Apk x86 embedded
#pack_Apk x86 shared
#pack_Apk arm embedded
#pack_Apk arm shared
#pack_Embeddingapi x86 embedded
#pack_Embeddingapi x86 shared
#pack_Embeddingapi arm embedded
#pack_Embeddingapi arm shared
#pack_Aio apk x86 embedded
#pack_Aio apk x86 shared
#pack_Aio apk arm embedded
#pack_Aio apk arm shared
#pack_Aio cordova x86 
#pack_Aio cordova arm 
#copy_SDK
#save_Package



recover_Tests usecase-webapi-xwalk-tests $CTS_DIR/usecase/usecase-webapi-xwalk-tests
recover_Tests usecase-wrt-android-tests $CTS_DIR/usecase/usecase-wrt-android-tests
recover_Tests usecase-cordova-android-tests $CTS_DIR/usecase/usecase-cordova-android-tests

