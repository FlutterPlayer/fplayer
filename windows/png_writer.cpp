#include "png_writer.h"

#ifndef NOMINMAX
#define NOMINMAX
#endif
#include <windows.h>
#include <wincodec.h>
#include <wrl/client.h>

#include <cstdint>
#include <limits>
#include <vector>

using Microsoft::WRL::ComPtr;

namespace {

bool ExtractStream(IStream* stream, std::vector<uint8_t>* output) {
  STATSTG stat = {};
  HRESULT hr = stream->Stat(&stat, STATFLAG_NONAME);
  if (FAILED(hr) || stat.cbSize.QuadPart == 0 ||
      stat.cbSize.QuadPart > std::numeric_limits<size_t>::max()) {
    return false;
  }

  LARGE_INTEGER start = {};
  hr = stream->Seek(start, STREAM_SEEK_SET, nullptr);
  if (FAILED(hr)) {
    return false;
  }

  output->resize(static_cast<size_t>(stat.cbSize.QuadPart));
  ULONG read = 0;
  hr = stream->Read(output->data(), static_cast<ULONG>(output->size()), &read);
  if (FAILED(hr) || read != output->size()) {
    output->clear();
    return false;
  }
  return true;
}

}  // namespace

bool EncodePng(const std::vector<uint8_t>& rgba, int width, int height,
               std::vector<uint8_t>* output) {
  if (output == nullptr || width <= 0 || height <= 0) {
    return false;
  }

  const size_t pixel_bytes =
      static_cast<size_t>(width) * static_cast<size_t>(height) * 4;
  if (rgba.size() < pixel_bytes ||
      pixel_bytes > std::numeric_limits<UINT>::max()) {
    return false;
  }

  output->clear();

  HRESULT hr = CoInitializeEx(nullptr, COINIT_MULTITHREADED);
  bool com_initialized = SUCCEEDED(hr);
  if (hr == RPC_E_CHANGED_MODE) {
    com_initialized = false;
  } else if (FAILED(hr)) {
    return false;
  }

  bool success = false;
  {
    ComPtr<IWICImagingFactory> factory;
    hr = CoCreateInstance(CLSID_WICImagingFactory, nullptr,
                          CLSCTX_INPROC_SERVER, IID_PPV_ARGS(factory.GetAddressOf()));
    if (SUCCEEDED(hr)) {
      ComPtr<IStream> stream;
      hr = CreateStreamOnHGlobal(nullptr, TRUE, stream.GetAddressOf());
      if (SUCCEEDED(hr)) {
        ComPtr<IWICBitmapEncoder> encoder;
        hr = factory->CreateEncoder(GUID_ContainerFormatPng, nullptr, encoder.GetAddressOf());
        if (SUCCEEDED(hr)) {
          hr = encoder->Initialize(stream.Get(), WICBitmapEncoderNoCache);
        }
        if (SUCCEEDED(hr)) {
          ComPtr<IWICBitmapFrameEncode> frame;
          ComPtr<IPropertyBag2> properties;
          hr = encoder->CreateNewFrame(frame.GetAddressOf(), properties.GetAddressOf());
          if (SUCCEEDED(hr)) {
            hr = frame->Initialize(properties.Get());
          }
          if (SUCCEEDED(hr)) {
            hr = frame->SetSize(static_cast<UINT>(width),
                                static_cast<UINT>(height));
          }

          WICPixelFormatGUID format = GUID_WICPixelFormat32bppRGBA;
          if (SUCCEEDED(hr)) {
            hr = frame->SetPixelFormat(&format);
          }
          if (SUCCEEDED(hr)) {
            ComPtr<IWICBitmap> bitmap;
            hr = factory->CreateBitmapFromMemory(
                static_cast<UINT>(width), static_cast<UINT>(height),
                GUID_WICPixelFormat32bppRGBA, static_cast<UINT>(width) * 4,
                static_cast<UINT>(rgba.size()),
                const_cast<BYTE*>(rgba.data()), bitmap.GetAddressOf());
            if (SUCCEEDED(hr)) {
              ComPtr<IWICFormatConverter> converter;
              hr = factory->CreateFormatConverter(converter.GetAddressOf());
              if (SUCCEEDED(hr)) {
                hr = converter->Initialize(
                    bitmap.Get(), format, WICBitmapDitherTypeNone, nullptr, 0.0,
                    WICBitmapPaletteTypeCustom);
              }
              if (SUCCEEDED(hr)) {
                hr = frame->WriteSource(converter.Get(), nullptr);
              }
            }
          }
          if (SUCCEEDED(hr)) {
            hr = frame->Commit();
          }
        }
        if (SUCCEEDED(hr)) {
          hr = encoder->Commit();
        }
        if (SUCCEEDED(hr)) {
          success = ExtractStream(stream.Get(), output);
        }
      }
    }
  }

  if (com_initialized) {
    CoUninitialize();
  }
  return success;
}
