#ifndef FPLAYER_PNG_WRITER_H_
#define FPLAYER_PNG_WRITER_H_

#include <cstdint>
#include <vector>

bool EncodePng(const std::vector<uint8_t>& rgba, int width, int height,
               std::vector<uint8_t>* output);

#endif  // FPLAYER_PNG_WRITER_H_
