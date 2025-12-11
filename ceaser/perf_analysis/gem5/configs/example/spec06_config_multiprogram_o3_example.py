"""Spec06 multiprogram wrapper that defaults to DerivO3CPU."""

import sys

if not any(arg.startswith('--cpu-type') for arg in sys.argv):
    sys.argv.append('--cpu-type=DerivO3CPU')
    sys.argv.append('--mem-type=DDR4_2400_8x8')

import spec06_config_multiprogram
