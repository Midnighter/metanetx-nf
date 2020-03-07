# metanetx-nf

Enrich the information coming from MetaNetX from additional sources.

## Usage

1. Set up nextflow as [described
   here](https://www.nextflow.io/index.html#GetStarted).
2. If you didn't run this pipeline in a while, possibly update nextflow itself.
    ```
    ./nextflow self-update
    ```
3. Then run the pipeline. Please specify an email parameter out of courtesy for
   logging into FTP servers.
    ```
    ./nextflow run https://github.com/Midnighter/metanetx-nf --email=your.name@place.earth
    ```

## Copyright

* Copyright © 2020, Moritz E. Beber.
* Free software distributed under the [Apache Software License
  2.0](https://www.apache.org/licenses/LICENSE-2.0).
