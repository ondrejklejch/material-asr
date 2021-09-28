// kwsbin/split-keywords.cc

// Copyright 2019 University of Edinburgh (Authors: Ondrej Klejch)

// See ../../COPYING for clarification regarding multiple authors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
// THIS CODE IS PROVIDED *AS IS* BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
// KIND, EITHER EXPRESS OR IMPLIED, INCLUDING WITHOUT LIMITATION ANY IMPLIED
// WARRANTIES OR CONDITIONS OF TITLE, FITNESS FOR A PARTICULAR PURPOSE,
// MERCHANTABLITY OR NON-INFRINGEMENT.
// See the Apache 2 License for the specific language governing permissions and
// limitations under the License.


#include "base/kaldi-common.h"
#include "util/common-utils.h"
#include "fstext/kaldi-fst-io.h"

int main(int argc, char *argv[]) {
  try {
    using namespace kaldi;
    using namespace fst;

    const char *usage =
        "Splits a keywords archive into multiple archives."
        "\n"
        "Usage: split-keywords --num-splits=10 <keywords-rspecifier> <ouput_dir>"
        " e.g.: split-keywords --num-splits=10 ark:keywords.fsts keywords_split ";

    ParseOptions po(usage);

    int32 n_splits = 1;

    po.Register("num-splits", &n_splits, "Number of splits");

    if (n_splits < 1) {
      KALDI_ERR << "Bad number for num-splits";
      exit(1);
    }

    po.Read(argc, argv);

    if (po.NumArgs() != 2) {
      po.PrintUsage();
      exit(1);
    }

    std::string keyword_rspecifier = po.GetArg(1),
        output_dir = po.GetArg(2);

    int32 n_done = 0;
    SequentialTableReader<VectorFstHolder> keyword_reader(keyword_rspecifier);
    vector<TableWriter<VectorFstHolder>*> keyword_writers;
    for (int32 i = 0; i < n_splits; ++i) {
      std::stringstream ss;
      ss << "ark:" << output_dir << "/keywords." << (i + 1) << ".fsts"; 
      keyword_writers.push_back(new TableWriter<VectorFstHolder>(ss.str()));
    }

    for (; !keyword_reader.Done(); keyword_reader.Next()) {
      keyword_writers[n_done % n_splits]->Write(keyword_reader.Key(), keyword_reader.Value()); 
      ++n_done;
    }

    KALDI_LOG << "Done " << n_done << " keywords";
    return 0;
  } catch(const std::exception &e) {
    std::cerr << e.what();
    return -1;
  }
}
