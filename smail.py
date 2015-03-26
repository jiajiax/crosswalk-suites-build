#!/usr/bin/python
#!encoding:utf-8

import sys
import os
import smtplib    
import commands
from email.mime.text import MIMEText    
from email.mime.multipart import MIMEMultipart    



def send_mail(vnum,address):

    sender = 'jiajiax.li@intel.com'    
    sto = 'jiajiax.li@intel.com,leix.wang@intel.com,jianhuix.a.yue@intel.com,xiax.li@intel.com,yunxiaox.lv@intel.com,canx.cao@intel.com,huihuix.z.sun@intel.com'
    scc = 'yunfeix.hao@intel.com,fengx.dai@intel.com,junx.b.li@intel.com,xiaoyux.zhang@intel.com'
    #sto = 'jiajiax.li@intel.com'
    #scc = 'jiajiax.li@intel.com'
    #scc = 'wanmingx.lin@intel.com'
    smtpserver = 'smtp.intel.com'    
    
    #username = 'jiajiax.li@intel.com'    
    #password = 'LIjia216559,'    
    #smtpserver = '10.239.52.22'    
    #username = 'orange'    
    #password = '0'    

    pkgaddress = "http://otcqa.sh.intel.com/qa-auto/live/Xwalk-testsuites/"+address
    branchnum = str(sys.argv[4]).strip()
    branchflag = int(vnum.split('.')[-1])
    if branchflag == 0:
        #pkglist = commands.getoutput('cd /home/orange/00_jiajia/release_build/WWrelease;tree').splitlines()
        if os.path.exists('/mnt/doc/toyunfei/01org/release/crosswalk/android/canary/%s'%vnum):
            toolsaddress = "outshare/doc/toyunfei/01org/release/crosswalk/android/canary/%s"%vnum
        else:
            toolsaddress = "%s not exists"%vnum
        
    else:
        #pkglist = commands.getoutput('cd /home/orange/00_jiajia/release_build/WWbeta;tree').splitlines()
        if os.path.exists('/mnt/doc/toyunfei/01org/release/crosswalk/android/beta/%s'%vnum):
            toolsaddress = "outshare/doc/toyunfei/01org/release/crosswalk/android/beta/%s"%vnum
        else:
            toolsaddress = "%s not exists"%vnum
        
    #msg = MIMEText('<html><h1>你好</h1></html>','html','utf-8')    
    
    msg = MIMEMultipart()
    
    logfile_dir = os.path.join(os.getcwd(), "logs", "canary_error.log")
    att1 = MIMEText(open(logfile_dir, 'rb').read(), 'base64', 'gb2312')
    att1["Content-Type"] = 'application/octet-stream'
    att1["Content-Disposition"] = 'attachment; filename="packed_failed_suites_list.log"'
    msg.attach(att1)

    msg['Subject'] = 'The test suites of %s version were built done !'%vnum
    msg['From'] = sender
    msg['To'] = sto
    msg['Cc'] = scc
    
    html = '<html>'
    html += '<head></head>'
    #html += '<body style="font-family:Times New Roman;">'
    html += '<body style="font-family:Calibri;">'
    html += '<p>Hi all,</p>'
    html += '<br><p>The test suites of <b><font color="#FF0000">%s</font></b> version were built done!</p>'%(vnum)
    html += '<p>Code Branch :  &nbsp;<b><font color="#FF0000">%s</font> </b></p>'%(branchnum)
    html += '<p>Commit ID :  &nbsp;<b>%s </b></p>'%(sys.argv[3])
    #html += '<p>Packages list:</p>'
    #for pkg in pkglist:
    #    html += '<p style="margin:0">&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;%s</p>'%pkg
    html += '<p>Tests Suites Address : &nbsp; <b><a href=%s>%s</a></b></p>'%(pkgaddress,pkgaddress)
    html += '<p>Crosswalk Tools %s : &nbsp; <b><a href=%s>%s</a></b></p>'%(vnum,toolsaddress,toolsaddress)
    html += '<br><p>If you have other needs ,please connect me by IM !</p>'
    html += '<br/><br/>'
    html += '<p>Best Regards</p>'
    html += '<p>Li Jiajia</p>'
    html += '</body>'
    html += '</html>'
    
    
    msgtext = MIMEText(html,'html','utf-8')
    msg.attach(msgtext)
    
     
    
    server = smtplib.SMTP(smtpserver)    
    #smtp.connect(smtpserver)    
    #smtp.ehlo()
    #smtp.starttls()
    #smtp.login(username, password)    
    receiver = sto + "," + scc
    server.sendmail(list(sender), receiver.split(','), msg.as_string().encode('utf-8'))    
    server.quit()    



if __name__ == '__main__':
    if len(sys.argv) >= 5:
        send_mail(sys.argv[1],sys.argv[2])
    else:
        print "arguments error !"
        sys.exit(1)

    
