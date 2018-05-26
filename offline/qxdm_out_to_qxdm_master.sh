source conf/conf.sh

#################
if [ -d ${QXDM_MASTER_DIR} ]
then
   rm -r ${QXDM_MASTER_DIR}
fi
mkdir -p ${QXDM_MASTER_DIR}

Rscript src/generateQxdmMaster.R ${QXDM_OUT_DIR} ${QXDM_MASTER_DIR} ${MIN_INTERBURST_TIME} ${MIN_INTERCHUNK_TIME} ${USERID_KPI} ${NUM_PRBS_PER_TTI} &> ${QXDM_MASTER_DIR}/log.txt

echo "END OF PROCESSING. SUCCESS!"

