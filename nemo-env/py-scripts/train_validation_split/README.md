# Train Validation split script

This folder contains a simple script to split Nemo Megatron formatted data for TrustLLM into train and validation splits.

The script `split.py` is responsible for doing the actual work. It is very much the simplest, rather than best, solution, and can be called as follows:

```
Usage: split.py [OPTIONS]

Options:
  --in_path TEXT       Input path (without file extensions .bin or .idx) for
                       megatron data pair.  [required]
  --left_path TEXT     Output path (without file extension .bin or .idx) for
                       the left (default: train) split.
  --right_path TEXT    Output path (without file extension .bin or .idx) for
                       the right (default: valid) split.
  --right_prob FLOAT   Probability of a sample ending up in the right (valid)
                       split. NOTE: The minimum (in expected number of
                       samples) of right_prob and right_max is chosen during
                       splitting.
  --right_max INTEGER  Approximate number of samples that should end up in the
                       right (valid) split. NOTE: The minimum (in expected
                       number of samples) of right_prob and right_max is
                       chosen during splitting.
  --seed INTEGER       Seed for the RNG
  --help               Show this message and exit.
```

# MN5-stuff

The rest is essentially for running it on MN5 and configuring what to run:

`split.def` contains a definition file for singularity which can be used to set up a container that can run the script (note that it does not depend on nemo, since we've essentially broken out the `indexed_dataset.py` file). 

`mk_script.py` is a combined script and configuration file that can be used to generate a simple sbatch script (defined by the `batch.template`) that splits a set of input files.


# Caveat

The scripts have not been made with portability or longevity in mind, but as a quick and dirty solution. That being said, they're very simple and should be portable with minimal effort.
