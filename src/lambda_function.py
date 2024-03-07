import boto3
import json
import logging
from botocore.exceptions import ClientError

dynamodb = boto3.resource('dynamodb')

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger()

def get_item(params):
    
    if params == None:
        logger.warn('パラメータを入力してください。足りないパラメータ：name, bounty')
        return None
    else:
        if 'name' in params.keys():
            if 'bounty' in params.keys():
                try:
                    table = dynamodb.Table('gang_of_straw')
                    response = table.get_item(Key=params)
                    print(f'レスポンスの内容：{response}')
                    if response.get('Item') == None:
                        return 0
                    else:
                        return response.get('Item')
                except ClientError as e:
                    if e.response['Error']['Code'] == 'ValidationException':
                        logger.warn('指定されたキー要素がスキーマと一致しません')
                        return 0
                    else:
                        raise e
            else:
                logger.warn('パラメータが足りません。足りないパラメータ：bounty')
                return 'bounty'
        else:
            logger.warn('パラメータが足りません。足りないパラメータ：name')
            return 'name'


def lambda_handler(event, context):
    item = get_item(event.get('queryStringParameters'))

    if item == None:
        return {
            'statusCode': 400,
            'body': 'パラメータを入力してください。足りないパラメータ：name, bounty'
        }
    elif (item == 'name') or (item == 'bounty'):
        return {
            'statusCode': 400,
            'body': f'パラメータに{item}を入力してください。'
        }
    elif item == 0:
        return {
            'statusCode': 400,
            'body': '該当する情報はありませんでした。'
        }
    else:
        return {
            'statusCode': 200,
            'body': json.dumps(item)
        }
