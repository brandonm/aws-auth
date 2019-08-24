#!/usr/bin/env bash

printerr() { printf "%s\n" "$*" >&2; }

aws-auth-check-tools() {
  ($* &> /dev/null && echo 1 ) || { printerr "$1 not installed" ; return 0 }
}

aws-auth-utils() {
  if [[ -z $1 || $1 == aws-auth-mfa-login ]] {
    printerr "-------------------------------------"
    printerr "Usage:  aws-auth-mfa-login <alias> <token>"
    printerr ""
    printerr "This function creates an AWS MFA session based on secrets and MFA arn stored in the password manager. After creating a session via AWS STS the following vars are set in the environment: AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY and AWS_SESSION_TOKEN"
    printerr "  - <alias>/aws-access-key-id - AWS access key to set."
    printerr "  - <alias>/aws-access-secret - AWS secret to set."
    printerr "  - <alias>/aws-mfa-arn - AWS MFA arn for two factor login."
    printerr
  }

  if [[ -z $1 || $1 == aws-auth-login ]] {
    printerr "--------------------------"
    printerr "Usage:  aws-auth-login} <alias>"
    printerr ""
    printerr " This sets environment AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY based on stored secrets in the password store pass." 
    printerr "  - <alias>/aws-access-key-id - AWS access key to set."
    printerr "  - <alias>/aws-access-secret - AWS secret to set."
    printerr
  }

  if [[ -z $1 || $1 == aws-auth-create-secret-access-keys ]] {
    printerr "--------------------------------------------"
    printerr "Usage:  aws-auth-create-secret-access-keys} <alias>"
    printerr ""
    printerr "Inserts entries into aws-auth-get-secret for:"
    printerr "  - <alias>/aws-access-key-id"
    printerr "  - <alias>/aws-access-secret"
    printerr
  }

  if [[ -z $1 || $1 == aws-auth-create-secret-mfa ]] {
    printerr "------------------------------------"
    printerr "Usage:  aws-auth-create-secret-mfa <alias>"
    printerr ""
    printerr "Inserts entry into aws-auth-get-secret for:"
    printerr "  - <alias>/aws-mfa-arn" 
    printerr
  }
  
  if [[ -z $1 || $1 == aws-auth-cleare ]] {
    printerr "------------------"
    printerr "Usage: ws-clear"
    printerr ""
    printerr "Clears AWS related environment variables and unalias the the aws command."
    printerr
  }

  if [[ -z $1 || $1 == aws-auth-activate-profile ]] {
    printerr "----------------------------------------"
    printerr "Usage:  aws-auth-activate-profile <profile>"
    printerr ""
    printerr "Activate the AWS <profile> and creates an alias for the aws command to append `--profile=<profile\>` to ensure the profile is used."
    printerr
  }

  if [[ -z $1 || $1 == aws-auth-deactivate-profile ]] {
    printerr "--------------------------------"
    printerr "Usage:  aws-auth-deactivate-profile"
    printerr ""
    printerr "De-activate the AWS <profile>."
    printerr
  }

  if [[ -z $1 || $1 == aws-auth-mfa-devices-for-user ]] {
    printerr "--------------------------------"
    printerr "Usage:  aws-auth-mfa-devices-for-user <user-name>"
    printerr ""
    printerr "Look up the MFA device for <user-name>."
    printerr
  }
  
}

aws-auth-get-secret() {

  if [[ $AWS_AUTH_PASSWORD_STORE = "OSX_KEYCHAIN" ]]; then
    echo $(security find-generic-password -a aws-auth -s $1 -w)
  else 
    echo $(pass ${1})
  fi
}

aws-auth-set-secret() {
  if [[ $AWS_AUTH_PASSWORD_STORE = "OSX_KEYCHAIN" ]]; then
    $(security add-generic-password -a aws-auth -s $1 -w)
  else 
    $(pass insert ${1})
  fi
  
}


aws-auth-activate-profile() {
  if [[ -z $1 || $1 = "-help" ]]; then
    aws-auth-utils aws-auth-activate-profile && return 0
  fi
  export AWS_PROFILE=$1
  alias aws='aws --profile $AWS_PROFILE'
}

aws-auth-deactivate-profile() {
  if [[ $1 = "-help" ]]; then
    aws-auth-utils aws-auth-deactivate-profile && return 0
  fi
  unset AWS_PROFILE
  unalias aws &> /dev/null
}


aws-auth-login() {
  if [[ -z $1 || $1 = "-help" ]]; then
    aws-auth-utils aws-auth-login && return 0
  fi

  aws-auth-clear
  export AWS_ACCESS_KEY_ID=$(aws-auth-get-secret ${1}/aws-access-key-id)
  export AWS_SECRET_ACCESS_KEY=$(aws-auth-get-secret ${1}/aws-access-secret)
}

aws-auth-mfa-login() {
  if [[ -z $1 || -z $2 || $1 = "-help" ]]; then
    aws-auth-utils aws-auth-mfa-login && return 0
  fi

  aws-auth-clear
  export AWS_ACCESS_KEY_ID=$(aws-auth-get-secret ${1}/aws-access-key-id)
  export AWS_SECRET_ACCESS_KEY=$(aws-auth-get-secret ${1}/aws-access-secret)

  _mfaSerialNumber=$(aws-auth-get-secret ${1}/aws-mfa-arn)
  
  if [[ ! -z $_mfaSerialNumber || ! -z $token ]]; then
    export _awsSessionToken=$(aws sts get-session-token --serial-number $_mfaSerialNumber --token-code $2)
  fi

  if [[ ! -z $_awsSessionToken ]]; then
    expire=$(echo $_awsSessionToken | jq -r '.Credentials.Expiration')
    export AWS_SESSION_TOKEN=$(echo $_awsSessionToken | jq -r '.Credentials.SessionToken')
    export AWS_SECRET_ACCESS_KEY=$(echo $_awsSessionToken | jq -r '.Credentials.SecretAccessKey')
    export AWS_ACCESS_KEY_ID=$(echo $_awsSessionToken | jq -r '.Credentials.AccessKeyId')
    echo MFA session valid until $expire >&1
  else
    echo WARNING: Could not obtain session token >&1
  fi
  unset _awsSessionToken
  unset _mfaSerialNumber

}

aws-auth-clear() {
  if [[ $1 = "-help" ]]; then
    aws-auth-utils aws-auth-clear && return 0
  fi
  unset AWS_SESSION_TOKEN
  unset AWS_SECRET_ACCESS_KEY
  unset AWS_ACCESS_KEY_ID

  if [[ ! $1 == 'only-env-vars' ]]; then
    aws-auth-deactivate-profile
    if [[ -d ~/.aws/cli/cache ]]; then
      rm -rf ~/.aws/cli/cache
    fi
  fi 
}


aws-auth-create-secret-mfa() {
  if [[ -z $1 || $1 = "-help" ]]; then
    aws-auth-utils aws-auth-create-secret-mfa && return 0
  fi
  aws-auth-set-secret ${1}/aws-mfa-arn
}

aws-auth-create-secret-access-keys() {
  if [[ -z $1 || $1 = "-help" ]]; then
    aws-auth-utils aws-auth-create-secret-access-keys && return 0
  fi
  aws-auth-set-secret ${1}/aws-access-key-id
  aws-auth-set-secret ${1}/aws-access-secret
}

aws-auth-mfa-devices-for-user() {
  if [[ -z $1 || $1 = "-help" ]]; then
    aws-auth-utils aws-auth-mfa-devices-for-user && return 0
  fi
  echo $(aws iam list-mfa-devices --user-name $1) | jq -r '.MFADevices[].SerialNumber'
}