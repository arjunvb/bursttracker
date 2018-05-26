echo "SETTING UP PATHS AND CONFIGURATION PARAMETERS"
set -eu -o pipefail

while getopts ":d:c:" opt; do
  case $opt in
     d) DATADIR="$OPTARG"
     ;;
     c) CONF_FILE="$OPTARG"
     ;;
     \?) echo "Invalid option -$OPTARG" >&2
     ;;
  esac
done

os=$( uname -a | cut -d ' ' -f 1 )
if [[ ${os} == "Linux" ]]; then
  DATADIR=$( readlink -f ${DATADIR} )
else
  # Mac OS X Requires: "brew install coreutils" package
  DATADIR=$( greadlink -f ${DATADIR} )
fi

echo "DATADIR AT"
echo ${DATADIR}

########################################
### SET DEFAULT PARAMS
########################################

# DEFAULT PATHS
CONF_DIR="${DATADIR}/conf"

QXDM_RAW_DIR="${DATADIR}/qxdm/raw"
QXDM_OUT_DIR="${DATADIR}/qxdm/out"
QXDM_MASTER_DIR="${DATADIR}/qxdm/master"
QXDM_PLOTS_DIR="${DATADIR}/qxdm/plots"

APP_DIR="${DATADIR}/app"

PLOTS_DIR="${DATADIR}/plots"

SUMMARY_DIR="${DATADIR}/summary"

# DEFAULT CONF PARAMS
MIN_INTERBURST_TIME=10 # TTIs
MIN_INTERCHUNK_TIME=600 # TTIs
USERID_KPI="IMEIX" 
NUM_PRBS_PER_TTI=50
EXTRA_IMEIX_LIST=""

########################################
### SOURCE RUNTIME CONF PARAMS
### (OVERRIDES DEFAULT CONF PARAMS)
########################################
if [ -z ${CONF_FILE+x} ]; then
  echo "Conf params file not specified"
else
  source ${CONF_FILE}
fi

