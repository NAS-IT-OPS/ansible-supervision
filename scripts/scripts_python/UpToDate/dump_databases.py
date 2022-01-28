#!/usr/bin/python3

###########################################################
#
# This python script is used for mysql database backup
# using mysqldump and tar utility.
#
# Written by : Valery NAHUM
# Created date: Nov 17, 2021
# Last modified: Nov 17, 2021 
# Tested with : Python 2.7.5 and python 3
#
##########################################################

# Import required python libraries

import os
import time
import datetime
import pipes
import shutil
from botocore.exceptions import NoCredentialsError
import tarfile

access_key = 'xxxxxxxxxxxxxx' # Change by the right access_key_id
access_secret = 'xxxxxxxxxxxxxxxxxxxx' # Change by the right secret_key_id
bucket_name = 'glpi_bucket_name' # Change by the right bucket_name


# MySQL database details to which backup to be done. Make sure below user having enough privileges to take databases backup.
# To take multiple databases backup, create any file like /backup/dbnames.txt and put databases names one on each line and assigned to DB_NAME variable.

DB_HOST = 'IP@_DB'                       # Change by the right DB_HOST
DB_USER = 'db_username'                  # Change by the right DB_USER
DB_USER_PASSWORD = 'password_of_db'      # Change by the right DB_USER_PASSWD
DB_NAME = '/path/to/db_name'             # Change by the right DB_NAME 
BACKUP_PATH = '/backup/backup_db'        # Change by the right BACKUP_PATH 


# Getting current DateTime to create the separate backup folder like "20180817-123433".
DATETIME = time.strftime('%Y%m%d-%H%M%S')
TODAYBACKUPPATH = BACKUP_PATH + '/' + DATETIME
LOG_FILE = '/backup/log_db/'  
TARGZFILE = TODAYBACKUPPATH + "_mysql-glpi-mig.tar.gz"
S3_FILE_NAME = DATETIME + "_mysql-glpi-mig.tar.gz"

# Checking if backup_path and LOG_FILE already exists or not. If not exists will create it.

try:
    os.stat(BACKUP_PATH)
except:
    os.mkdir(BACKUP_PATH)

try:
    os.stat(LOG_FILE)
except:
    os.mkdir(LOG_FILE)

# Checking if backup folder already exists or not. If not exists will create it.
try:
    os.stat(TODAYBACKUPPATH)
except:
    os.mkdir(TODAYBACKUPPATH)


# Code for checking if you want to take single database backup or assigned multiple backups in DB_NAME.
print ("checking for databases names file.")
if os.path.exists(DB_NAME):
    file1 = open(DB_NAME)
    multi = 1
    print ("Databases file found...")
    print ("Starting backup of all dbs listed in file " + DB_NAME)
else:
    print ("Databases file not found...")
    print ("Starting backup of database " + DB_NAME)
    multi = 0

# Starting actual database backup process.
if multi:
   in_file = open(DB_NAME,"r")
   flength = len(in_file.readlines())
   in_file.close()
   p = 1
   dbfile = open(DB_NAME,"r")

   while p <= flength:
       db = dbfile.readline()   # reading database name from file
       db = db[:-1]         # deletes extra line
       dumpcmd = "mysqldump -h " + DB_HOST + " -u " + DB_USER + " -p" + DB_USER_PASSWORD + " " + db + " --single-transaction " + " > " + pipes.quote(TODAYBACKUPPATH) + "/" + db + ".sql"
       os.system(dumpcmd)
       print("")
       print("Compressing of Database " + db )
       gzipcmd = "gzip " + pipes.quote(TODAYBACKUPPATH) + "/" + db + ".sql"
       os.system(gzipcmd)
       print("End of compression " + db )
       p = p + 1
   dbfile.close()
else:
   db = DB_NAME
   dumpcmd = "mysqldump -h " + DB_HOST + " -u " + DB_USER + " -p" + DB_USER_PASSWORD + " " + db + " > " + pipes.quote(TODAYBACKUPPATH) + "/" + db + ".sql"
   os.system(dumpcmd)
   gzipcmd = "gzip " + pipes.quote(TODAYBACKUPPATH) + "/" + db + ".sql"
   os.system(gzipcmd)


# Compressing folder 'TODAYBACKUPPATH' to tar.gz
print("Compressing of " + TODAYBACKUPPATH)
TAR = tarfile.open(TARGZFILE ,"w:gz")
TARCMDFOLDER = TAR.add(TODAYBACKUPPATH , arcname=None)
TAR.close()

# Function to upload archive .tar.gz to bucket s3
def upload_to_aws(local_file, bucket, s3_file):

    s3 = boto3.client('s3')

    try:
        s3.upload_file(local_file, bucket, s3_file)
        print("Upload Successful")
        return True
    except FileNotFoundError:
        print("The file was not found")
        return False
    except NoCredentialsError:
        print("Credentials not available")
        return False

if os.path.isfile(TARGZFILE):
    print("Copying compression database from s3 bucket")
    uploaded = upload_to_aws(TARGZFILE , "databases-glpi-backup-1635253440", S3_FILE_NAME)
    print("Upload to bucket s3 successfully")
else:
    print("File " + TARGZFILE + " doesn't exist")
    print("You cannot copy " + targzfile)

if os.path.isdir(TODAYBACKUPPATH):
    print("Folder " + TODAYBACKUPPATH + " exist and will be deleted")
    shutil.rmtree(TODAYBACKUPPATH,ignore_errors=False,onerror=None)
    print("Folder " + TODAYBACKUPPATH + " has been deleted")

if os.path.isfile(TARGZFILE):
    print("File " + TARGZFILE + " exist and will be deleted")
    os.remove(TARGZFILE)
    print("File " + TARGZFILE + " has been deleted")
else:
    print("File "+ TARGZFILE + " doesn't exist")

print ("")
print ("Backup script completed")
print ("Your backups have been created in '" + TODAYBACKUPPATH + "' directory")
print("Backup compression has been send to s3 bucket")


