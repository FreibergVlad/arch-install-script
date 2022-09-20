set -euo pipefail
trap 's=$?; echo "$0: Error on line "$LINENO": $BASH_COMMAND"; exit $s' ERR

# log message to log file and stdout both
log() {
    echo "$1" | tee -a $log_file
}

# execute bash command and log its output:
#   - stdout goes to log file
#   - stderr goes to log file and stdout both
exec_with_log() {
    local cmd=$@
    eval $cmd 2>> >(tee -a $log_file) 1>>$log_file
}
