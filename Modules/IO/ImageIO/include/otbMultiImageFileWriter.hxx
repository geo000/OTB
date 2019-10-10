/*
 * Copyright (C) 2017-2019 CS Systemes d'Information (CS SI)
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

#ifndef otbMultiImageFileWriter_hxx
#define otbMultiImageFileWriter_hxx

#include "otbMultiImageFileWriter.h"
#include "otbImageIOFactory.h"
#include "otbMacro.h"

namespace otb
{

template <class TImage>
MultiImageFileWriter::Sink<TImage>::Sink(typename TImage::ConstPointer inputImage, const std::string& fileName)
  : SinkBase(dynamic_cast<const ImageBaseType*>(inputImage.GetPointer()))
{
  auto writer = otb::ImageFileWriter<TImage>::New();
  writer->SetFileName(fileName);
  writer->SetInput(inputImage);
  
  m_Writer = writer;
}

template <class TImage>
MultiImageFileWriter::Sink<TImage>::Sink(typename otb::ImageFileWriter<TImage>::ConstPointer writer)
  : SinkBase(dynamic_cast<const ImageBaseType*>(writer->GetInput()->GetPointer())), m_Writer(writer)
{
}

template <class TImage>
MultiImageFileWriter::Sink<TImage>::Sink(typename otb::ImageFileWriterBase::Pointer writer)
  : SinkBase(const_cast<ImageBaseType*>(writer->GetImageBaseInput())), m_Writer(writer)
{
}

template <class TImage>
bool MultiImageFileWriter::Sink<TImage>::CanStreamWrite()
{
  return m_Writer->CanStreamWrite();
}

template <class TImage>
void MultiImageFileWriter::Sink<TImage>::WriteImageInformation()
{
  m_Writer->UpdateOutputInformation();
}

template <class TImage>
void MultiImageFileWriter::Sink<TImage>::Write(const RegionType& streamRegion)
{
  // Write the image stream
  itk::ImageIORegion ioRegion(TImage::ImageDimension);
  for (unsigned int i = 0; i < TImage::ImageDimension; ++i)
  {
    ioRegion.SetSize(i, streamRegion.GetSize(i));
    ioRegion.SetIndex(i, streamRegion.GetIndex(i));
  }
  m_Writer->SetIORegion(ioRegion);
  m_Writer->UpdateOutputData(nullptr);
}

} // end of namespace otb

#endif // otbMultiImageFileWriter_hxx
