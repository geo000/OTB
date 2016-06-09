find_package(Shark REQUIRED)
include(${SHARK_USE_FILE})
otb_add_test(NAME leTuSharkRFMachineLearningModelNew COMMAND otbSupervisedTestDriver
  otbSharkRFMachineLearningModelNew)

otb_add_test(NAME leTvSharkRFMachineLearningModel COMMAND otbSupervisedTestDriver
  otbSharkRFMachineLearningModel
  ${INPUTDATA}/letter.scale
  ${TEMP}/shark_rf_model.txt
  )

otb_add_test(NAME leTuSharkRFMachineLearningModelCanRead COMMAND otbSupervisedTestDriver
  otbSharkRFMachineLearningModelCanRead
  ${TEMP}/shark_rf_model.txt
  )

otb_add_test(NAME leTuSharkRFMachineLearningModelCanReadFail COMMAND otbSupervisedTestDriver
  otbSharkRFMachineLearningModelCanRead
  ${INPUTDATA}/ROI_QB_MUL_4_svmModel.txt
  )
set_property(TEST leTuSharkRFMachineLearningModelCanReadFail PROPERTY WILL_FAIL true)

# otb_add_test(NAME leTvImageClassificationFilterSVM COMMAND otbSupervisedTestDriver
#   --compare-image ${NOTOL}
#   ${BASELINE}/leImageClassificationFilterSVMOutput.tif
#   ${TEMP}/leImageClassificationFilterSVMOutput.tif
#   otbImageClassificationFilter
#   ${INPUTDATA}/ROI_QB_MUL_4.tif
#   ${INPUTDATA}/ROI_QB_MUL_4_svmModel.txt
#   ${TEMP}/leImageClassificationFilterSVMOutput.tif
#   )