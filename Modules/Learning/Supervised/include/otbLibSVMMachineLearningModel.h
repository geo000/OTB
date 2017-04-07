/*
 * Copyright (C) 2005-2017 Centre National d'Etudes Spatiales (CNES)
 *
 * This file is part of Orfeo Toolbox
 *
 *     https://www.orfeo-toolbox.org/
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#ifndef otbLibSVMMachineLearningModel_h
#define otbLibSVMMachineLearningModel_h

#include "itkLightObject.h"
#include "itkFixedArray.h"
#include "otbMachineLearningModel.h"

#include "svm.h"

namespace otb
{
template <class TInputValue, class TTargetValue>
class ITK_EXPORT LibSVMMachineLearningModel
  : public MachineLearningModel <TInputValue, TTargetValue>
{
public:
  /** Standard class typedefs. */
  typedef LibSVMMachineLearningModel           Self;
  typedef MachineLearningModel<TInputValue, TTargetValue> Superclass;
  typedef itk::SmartPointer<Self>                         Pointer;
  typedef itk::SmartPointer<const Self>                   ConstPointer;

  typedef typename Superclass::InputValueType             InputValueType;
  typedef typename Superclass::InputSampleType            InputSampleType;
  typedef typename Superclass::InputListSampleType        InputListSampleType;
  typedef typename Superclass::TargetValueType            TargetValueType;
  typedef typename Superclass::TargetSampleType           TargetSampleType;
  typedef typename Superclass::TargetListSampleType       TargetListSampleType;
  typedef typename Superclass::ConfidenceValueType        ConfidenceValueType;

  /** Run-time type information (and related methods). */
  itkNewMacro(Self);
  itkTypeMacro(SVMMachineLearningModel, MachineLearningModel);

  /** Train the machine learning model */
  void Train() ITK_OVERRIDE;

  /** Save the model to file */
  void Save(const std::string &filename, const std::string & name="") ITK_OVERRIDE;

  /** Load the model from file */
  void Load(const std::string & filename, const std::string & name="") ITK_OVERRIDE;

  /**\name Classification model file compatibility tests */
  //@{
  /** Is the input model file readable and compatible with the corresponding classifier ? */
  bool CanReadFile(const std::string &) ITK_OVERRIDE;

  /** Is the input model file writable and compatible with the corresponding classifier ? */
  bool CanWriteFile(const std::string &) ITK_OVERRIDE;
  //@}

#define otbSetSVMParameterMacro(name, alias, type) \
  void Set##name (const type _arg)                                \
    {                                                             \
    itkDebugMacro("setting " #name " to " << _arg); \
    if ( this->m_Parameters.alias != _arg )                      \
      {                                                           \
      this->m_Parameters.alias = _arg;                           \
      this->Modified();                                           \
      }                                                           \
    }

  /** Set the SVM type to C_SVC, NU_SVC, ONE_CLASS, EPSILON_SVR, NU_SVR */
  otbSetSVMParameterMacro(SVMType, svm_type, int)

  /** Get the SVM type (C_SVC, NU_SVC, ONE_CLASS, EPSILON_SVR, NU_SVR) */
  int GetSVMType(void) const
    {
    return m_Parameters.svm_type;
    }

  /** Set the kernel type to LINEAR, POLY, RBF, SIGMOID
  linear: u'*v
  polynomial: (gamma*u'*v + coef0)^degree
  radial basis function: exp(-gamma*|u-v|^2)
  sigmoid: tanh(gamma*u'*v + coef0)*/
  otbSetSVMParameterMacro(KernelType, kernel_type, int)

  /** Get the kernel type */
  int GetKernelType(void) const
    {
    return m_Parameters.kernel_type;
    }

  /** Set the degree of the polynomial kernel */
  otbSetSVMParameterMacro(PolynomialKernelDegree,degree,int)

  /** Get the degree of the polynomial kernel */
  int GetPolynomialKernelDegree(void) const
    {
    return m_Parameters.degree;
    }

  /** Set the gamma parameter for poly/rbf/sigmoid kernels */
  otbSetSVMParameterMacro(KernelGamma,gamma,double)

  /** Get the gamma parameter for poly/rbf/sigmoid kernels */
  double GetKernelGamma(void) const
    {
    return m_Parameters.gamma;
    }

  /** Set the coef0 parameter for poly/sigmoid kernels */
  otbSetSVMParameterMacro(KernelCoef0,coef0,double)

  /** Get the coef0 parameter for poly/sigmoid kernels */
  double GetKernelCoef0(void) const
  {
    return m_Parameters.coef0;
  }

  /** Set the C parameter for the training for C_SVC, EPSILON_SVR and NU_SVR */
  otbSetSVMParameterMacro(C,C,double)

  /** Get the C parameter for the training for C_SVC, EPSILON_SVR and NU_SVR */
  double GetC(void) const
    {
    return m_Parameters.C;
    }

  itkSetMacro(ParameterOptimization, bool);
  itkGetMacro(ParameterOptimization, bool);

  /** Do probability estimates */
  void DoProbabilityEstimates(bool prob)
    {
    m_Parameters.probability = static_cast<int>(prob);
    }

  /** Get Do probability estimates boolean */
  bool GetDoProbabilityEstimates(void) const
    {
    return static_cast<bool>(m_Parameters.probability);
    }

  /** Test if the model has probabilities */
  bool HasProbabilities(void) const;

  /** Set the tolerance for the stopping criterion for the training*/
  otbSetSVMParameterMacro(Epsilon,eps,double)

  /** Get the tolerance for the stopping criterion for the training*/
  double GetEpsilon(void) const
  {
    return m_Parameters.eps;
  }

  /** Set the value of p for EPSILON_SVR */
  otbSetSVMParameterMacro(P,p,double)

  /** Get the value of p for EPSILON_SVR */
  double GetP(void) const
  {
    return m_Parameters.p;
  }

  /** Set the Nu parameter for the training */
  otbSetSVMParameterMacro(Nu,nu,double)

  /** Set the Nu parameter for the training */
  double GetNu(void) const
  {
    return m_Parameters.nu;
  }

#undef otbSetSVMParameterMacro

  /** Use the shrinking heuristics for the training */
  void DoShrinking(bool s)
  {
    m_Parameters.shrinking = static_cast<int>(s);
    this->Modified();
  }

  /** Get Use the shrinking heuristics for the training boolea */
  bool GetDoShrinking(void) const
  {
    return static_cast<bool>(m_Parameters.shrinking);
  }

  /** Set the cache size in MB for the training */
  void SetCacheSize(int cSize)
  {
    m_Parameters.cache_size = static_cast<double>(cSize);
    this->Modified();
  }

  /** Get the cache size in MB for the training */
  int GetCacheSize(void) const
  {
    return static_cast<int>(m_Parameters.cache_size);
  }

protected:
  /** Constructor */
  LibSVMMachineLearningModel();

  /** Destructor */
  ~LibSVMMachineLearningModel() ITK_OVERRIDE;

  /** Predict values using the model */
  TargetSampleType DoPredict(const InputSampleType& input, ConfidenceValueType *quality=ITK_NULLPTR) const ITK_OVERRIDE;

  /** PrintSelf method */
  void PrintSelf(std::ostream& os, itk::Indent indent) const ITK_OVERRIDE;

private:
  LibSVMMachineLearningModel(const Self &); //purposely not implemented
  void operator =(const Self&); //purposely not implemented

  void BuildProblem(void);

  void ConsistencyCheck(void);

  void DeleteProblem(void);

  void DeleteModel(void);

  double CrossValidation(unsigned int nbFolders);

  void OptimizeParameters(void);

  /** Container to hold the SVM model itself */
  struct svm_model* m_Model;

  /** Structure that stores training vectors */
  struct svm_problem m_Problem;

  /** Container of the SVM parameters */
  struct svm_parameter m_Parameters;

  /** Do parameters optimization, default : false */
  bool m_ParameterOptimization;

  /** Temporary array to store cross-validation results */
  std::vector<double> m_TmpTarget;

};
} // end namespace otb

#ifndef OTB_MANUAL_INSTANTIATION
#include "otbLibSVMMachineLearningModel.txx"
#endif

#endif
