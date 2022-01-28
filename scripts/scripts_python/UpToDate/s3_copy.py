#!/usr/bin/python3

import os
import boto3
#from .s3_copy import upload_to_aws 
from botocore.exceptions import NoCredentialsError


def upload_to_aws(local_file, bucket, s3_file):
    #s3 = boto3.client('s3',
#		      aws_access_key_id=ACCESS_KEY,
#                      aws_secret_access_key=SECRET_KEY)
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

uploaded = upload_to_aws("/backup/backup_db/20220118-093852_mysql-glpi-mig.tar.gz", "databases-glpi-backup-1635253440", '20220118-093852_mysql-glpi-mig.tar.gz')

#uploaded = upload_to_aws(local_file, bucket_name, 's3_file_name')
#s3 = boto3.resource('s3', aws_access_key_id=ACCESS_KEY, aws_secret_access_key=SECRET_KEY)
#s3 = boto3.resource('s3')
#s3.meta.client.upload_file(Filename= '/backup/script/dump_databases.py', Bucket= 'databases-glpi-backup-1635253440', Key='save1.py')
#s3.meta.client.upload_file(Filename= '/backup/backup_db/20220109-234501/PRDGLP001.sql.gz', Bucket= 'databases-glpi-backup-1635253440', Key='PRDGLP001.sql.gz')

