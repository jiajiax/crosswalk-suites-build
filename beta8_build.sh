#!/bin/bash

. /etc/profile
export PATH=/usr/tizen-sdk/tools:/usr/java/sdk/tools:/usr/java/sdk/platform-tools:/usr/java/jdk1.7.0_67/bin:/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/games:/usr/local/games
script_dir=$(dirname $(readlink -f $0))
cts_dir=$script_dir/../work_space/release/beta8-crosswalk-test-suite
WW_dir=$script_dir/WWbeta
log_dir=$script_dir/logs
pkg_tools=$cts_dir/../pkg_tools
source $script_dir/beta8_list
branch=$1
if [ $branch -eq 7 ];then
	version_file=$script_dir/Beta7_Number
elif [ $branch -eq 8 ];then
	version_file=$script_dir/Beta8_Number
else
	echo "branch error !!!"
	exit 1
fi
version_num=`cat $version_file`
function prepare_tools(){
	cd $cts_dir/tools
	rm -rf crosswalk cordova XWalkRuntimeLib.apk
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
			echo "crosswalk-$version_num not exist !!!" >> $log_dir/tools_error.log
			exit 1
		
		fi
	else
		echo "arguments error !!!"
	fi
	

}


function sync_code(){
    # Get latest code from github
	#cd $demoex_dir ; git reset --hard HEAD;git pull ; cd -
	find $WW_dir -type f -name "*.zip" | xargs rm
	cd $cts_dir ;git reset --hard HEAD;git checkout Crosswalk-$1 ;git pull
    beta_commit=`git log -1 --pretty=oneline | awk '{print $1}'`
    beta_branch=`git branch | grep -E "^\*" | awk '{print $2}'`
    cd -
}


function pack_apk ()
{
	prepare_tools $1
    for apk in $APKLIST;do
        num=`find $cts_dir -name $apk -type d |wc -l`
        if [ $num -eq 1 ];then
            apk_dir=`find $cts_dir -name $apk -type d`
			if [ $apk = "webapi-sampleapp-embedding-tests" ];then
				rm -rf $apk_dir/../xwalk_core_library
				cp -a $cts_dir/tools/cordova/framework/xwalk_core_library $apk_dir/../
				cd $apk_dir
            	./pack.sh -t apk -a $1 
			else
				cd $apk_dir
				./pack.sh -t apk -m embedded -a $1
			fi
            if [ $? -eq 0 ];then
				mv *.zip $WW_dir/android/separate/$1/
			else
                echo "$apk failed">>$script_dir/logs/beta8_error.log
            fi
            echo $apk_dir
			cd -
        else
            echo "$apk Not unique" 
        fi
    done
}

function pack_cordova_arm(){
	prepare_tools arm
    for cordova_arm in $CORDOVALIST;do
		if [ $branch -eq 7 ] && [ $cordova_arm = "cordova-usecase-android-tests" ];then
			continue
		fi
        num=`find $cts_dir -name $cordova_arm -type d |wc -l`
        if [ $num -eq 1 ];then
            cordova_arm_dir=`find $cts_dir -name $cordova_arm -type d`
			cd $cordova_arm_dir
			if [ $cordova_arm = "webapi-usecase-w3c-tests" ];then
				./wpack.sh -t cordova
			else
				./pack.sh -t cordova
			fi
            if [ $? -eq 0 ];then
				mv *.zip $WW_dir/android/cordova/arm/
			else
                echo "$cordova_arm failed">>$script_dir/logs/beta8_error.log
            fi
            echo $cordova_arm_dir
			cd -
	    else
            echo "$cordova_arm Not unique"    
        fi
    done
}


echo "" > $script_dir/logs/beta8_error.log

function save_package(){ 
    end_time=`date +%m-%d-%H%M` 
    cp -a $WW_dir /data/pkgs/beta_WW_pkgs/$version_num"~"$end_time
	wweek=$(date +"%W" -d "+1 weeks")
	wtoday=$[$(date +%w)]
	wdir="WW"$wweek
	
	mkdir -p /mnt/otcqa/$wdir/{beta/"ww"$wweek"."$wtoday,master,stable,webtestingservice}
	if [ $? -eq 0 ];then
		chmod -R 777 $WW_dir
		cp -a $WW_dir /mnt/otcqa/$wdir/beta/"ww"$wweek"."$wtoday/$version_num"~"$end_time
	fi
    
    pkgaddress=$wdir/beta/"ww"$wweek"."$wtoday/$version_num"~"$end_time
    python /home/orange/00_jiajia/release_build/smail.py $version_num $pkgaddress $beta_commit $beta_branch
 
} 

if [ $# -eq 0 ] || [ $# -gt 1 ];then
	echo "please ensure the branch number 7 or 8 ?"
	exit 1
fi

sync_code $branch
#pack_wgt
#pack_xpk
pack_cordova_arm
pack_apk x86
pack_apk arm
#pack_apk_arm
#pack_aio x86
#pack_aio arm
save_package
