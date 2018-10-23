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

#include "itkMacro.h"
#include "otbFunctorImageFilter.h"
#include "otbImage.h"
#include "otbVectorImage.h"
#include "itkNeighborhood.h"
#include <tuple>

#include <numeric>

// Example functors

// N scalar images -> image
// This functor takes N scalar image (variadic N) and returns the sum
// of all pixels
template <typename O, typename ...T> struct VariadicAdd
{
  auto operator()(T... ins) const
  {
    std::vector<O> outVector{static_cast<O>(ins)...};

    return std::accumulate(outVector.begin(), outVector.end(),0);
  }
};

// helper function to implement next functor (convert a scalar value
// to a VariableLengthVector)
template <typename T> itk::VariableLengthVector<T> toVector(const T & in)
{
  itk::VariableLengthVector<T> out;
  out.SetSize(1);
  out[0] = in;
  return out;
}

// helper function to implement next functor, VariableLengthVectorVersion (returns in)
template <typename  T> const itk::VariableLengthVector<T> & toVector(const itk::VariableLengthVector<T> & in)
{
  return in;
}

// helper function to implement next functor, Merge two VariableLengthVector in-place
template <typename v1, typename v2> void concatenateVectors(v1 & a, const v2 & b)
{
  const size_t previousSizeOfA = a.GetSize();
  
  a.SetSize(previousSizeOfA+b.GetSize());
  
  for(size_t it = 0; it<b.Size();++it)
    {
    a[previousSizeOfA+it] = static_cast<typename v1::ValueType>(b[it]);
    }
}

// helper function to implement next functor, Merge N VariableLengthVector in-place
template <typename v1, typename v2, typename ...vn> void concatenateVectors(v1 & a, const v2 & b, const vn&... z)
{
  concatenateVectors(a,b);
  concatenateVectors(a,z...);
}

// N  images (all types) -> vector image
// This functor concatenates N images (N = variadic) of type
// VectorImage and or Image, into a single VectorImage
template<typename O, typename ...T> struct VariadicConcatenate
{
  auto operator()(const T &...  ins) const
  {
    itk::VariableLengthVector<O> out;
    concatenateVectors(out, toVector(ins)...);
    
    return out;
  }

  // Must define OutputSize because output pixel is vector
  constexpr size_t OutputSize(const std::array<size_t, sizeof...(T)> inputsNbBands) const
  {
    return std::accumulate(inputsNbBands.begin(),inputsNbBands.end(),0);
  }
};


// 1 VectorImage -> 1 VectorImage with a different size depending on a
// parameter of the functor
// This Functor 
template<typename O, typename T> struct BandExtraction
{
  BandExtraction(unsigned int indices...) : m_Indices({indices})
  {}
  
  // TODO define a constructor to initialize m_Indices  
  auto operator()(const itk::VariableLengthVector<T> & in) const
  {
    itk::VariableLengthVector<O> out(m_Indices.size());

    size_t idx = 0;
    for(auto v: m_Indices)
      {
      out[idx] = static_cast<O>(in[v]);
      ++idx;
      }

    return out;
  }

  // This time OutputSize does not depend on input image size, hence
  // the ...
  size_t OutputSize(...) const
  {
    return m_Indices.size();
  }
  
  // set of band indices to extract
  std::set<unsigned int> m_Indices;
};

// 1 Image with neighborhood -> 1 Image
// This Functor computes the mean in neighborhood
template<typename TOut, typename TIn> struct Mean
{  
  auto operator()(const itk::Neighborhood<TIn> & in) const
  {
    TOut out(0);

    for(auto it = in.Begin(); it!=in.End();++it)
      out+=static_cast<TOut>(*it);

    out/=in.Size();
    
    return out;
  }
};

// 1 Image with neighborhood of VariableLengthVector -> 1 image with
// VariableLengthVector
// For each channel, returns the maximum value in neighborhood
template<typename T> struct MaxInEachChannel
{
  auto operator()(const itk::Neighborhood<itk::VariableLengthVector<T>> & in) const
  {
    auto out = in.GetCenterValue();

    for(auto it = in.Begin(); it!=in.End(); ++it)
      {
      for(auto band = 0u; band < out.Size();++band)
        {
        if((*it)[band]>out[band])
          out[band] = (*it)[band];
        }
      }
    return out;
  }

  size_t OutputSize(const std::array<size_t,1> & nbBands) const
  {
    return nbBands[0];
  } 
};


using OImage = typename otb::Image<int>;
using Neig = typename itk::Neighborhood<int>;

static_assert(otb::IsNeighborhood<Neig>::value, "err");
static_assert(!otb::IsNeighborhood<double>::value, "err");
static_assert(!otb::IsNeighborhood<itk::VariableLengthVector<double>>::value, "err");


using namespace otb::functor_filter_details;
using namespace otb;

int otbFunctorImageFilter(int itkNotUsed(argc), char * itkNotUsed(argv) [])
{
  // test functions in functor_filter_details namespace
  using VectorImageType = VectorImage<double>;
  using ImageType       = Image<double>;
  using RegionType      = typename ImageType::RegionType;
  using SizeType        = typename RegionType::SizeType;
  
  auto vimage = VectorImageType::New();
  auto image  = ImageType::New();

  SizeType size = {{200,200}};
  
  vimage->SetRegions(size);
  vimage->SetNumberOfComponentsPerPixel(2);
  vimage->Allocate();
  itk::VariableLengthVector<double> v(2);
  v.Fill(0);
  vimage->FillBuffer(v);
  
  image->SetRegions(size);
  image->Allocate();
  image->FillBuffer(0);

  // Test VariadicInputsImageFilter
  auto filter = otb::VariadicInputsImageFilter<VectorImageType,VectorImageType,ImageType>::New();
  filter->SetVInput<0>(vimage);
  filter->SetVInput<1>(image);
  filter->SetVInputs(vimage,image);
  std::cout<<filter->GetVInput<0>()<< filter->GetVInput<1>()<<std::endl;

  
  // test FunctorImageFilter with a lambda
  double scale = 10.;  
  auto Lambda1 = [scale](double p)
               {
                 return scale*p;
               };
  auto filterLambda = NewFunctorFilter(Lambda1);
  filterLambda->SetVInputs(image);
  filterLambda->Update();

  // test FunctorImageFilter with a lambda that returns a
  // VariableLengthVector
  // Converts a neighborhood to a VariableLengthVector
  auto Lambda2 = [](const itk::Neighborhood<double> & in)
                 {
                   itk::VariableLengthVector<double> out(in.Size());
                   std::size_t idx{0};
                   for(auto it = in.Begin(); it!=in.End();++it,++idx)
                     {
                     out[idx]=*it;
                     }
                   return out;
                 };

  // In this case, we use the helper function which allows to specify
  // the number of outputs
  auto filterLambda2  = NewFunctorFilter(Lambda2,vimage->GetNumberOfComponentsPerPixel(),{{3,3}});
  filterLambda2->SetVInputs(image);
  filterLambda2->Update();
  
  // Test FunctorImageFilter with the VariadicConcatenate operator
  using ConcatFunctorType = VariadicConcatenate<double, double, itk::VariableLengthVector<double> >;
  auto concatenate = NewFunctorFilter(ConcatFunctorType{});
  concatenate->SetVInputs(image,vimage);
  concatenate->Update();
  
  // Test FunctorImageFilter With VariadicAdd functor
  using AddFunctorType = VariadicAdd<double, double, double>;
  auto add = NewFunctorFilter(AddFunctorType{});
  add->SetVInputs(image,image);
  add->Update();

  // Test FunctorImageFilter with BandExtraction functor
  using ExtractFunctorType = BandExtraction<double,double>;
  ExtractFunctorType extractFunctor{1,2};
  auto extract = NewFunctorFilter(extractFunctor);
  extract->SetVInputs(vimage);
  extract->Update();
  
  // Test FunctorImageFilter With Mean functor
  using MeanFunctorType = Mean<double,double>;
  auto median = NewFunctorFilter(MeanFunctorType{},{{2,2}});
  median->SetVInputs(image);
  median->Update();

  // Test FunctorImageFilter with MaxInEachChannel
  using MaxInEachChannelType = MaxInEachChannel<double>;
  auto maxInEachChannel = NewFunctorFilter(MaxInEachChannelType{},{{3,3}});
  maxInEachChannel->SetVInputs(vimage);
  maxInEachChannel->Update();
  
 return EXIT_SUCCESS;
}
