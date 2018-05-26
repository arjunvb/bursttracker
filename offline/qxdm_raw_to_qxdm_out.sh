source conf/conf.sh

#################
if [ -d ${QXDM_OUT_DIR} ]
then
   rm -r ${QXDM_OUT_DIR}
fi
mkdir -p ${QXDM_OUT_DIR}

NUM_FILES=$( ls ${QXDM_RAW_DIR}/*/qxdm_out.csv | wc -l )

echo "*****************************************" > ${QXDM_OUT_DIR}/log.txt
echo "Found"${NUM_FILES}" qxdm_out.csv files" >> ${QXDM_OUT_DIR}/log.txt
echo "*****************************************" >> ${QXDM_OUT_DIR}/log.txt
echo "Copying them over to "${QXDM_OUT_DIR}"..." >> ${QXDM_OUT_DIR}/log.txt

for INSTANCE in $( ls ${QXDM_RAW_DIR}/ )
do
    cp ${QXDM_RAW_DIR}/${INSTANCE}/qxdm_out.csv ${QXDM_OUT_DIR}/QXDM.TTIS.${INSTANCE}.csv
    echo "...copied "${QXDM_RAW_DIR}/${INSTANCE}"/qxdm_out.csv" >> ${QXDM_OUT_DIR}/log.txt
done

echo "*****************************************" >> ${QXDM_OUT_DIR}/log.txt
echo "END OF PROCESSING. SUCCESS!" >> ${QXDM_OUT_DIR}/log.txt
echo "END OF PROCESSING. SUCCESS!"

