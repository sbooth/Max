#!/bin/sh

if [ -f tests/sfversion ]; then
	cd tests
	fi

if [ ! -f sfversion ]; then
	echo "Not able to find test executables."
	exit 1
	fi

sfversion=`./sfversion`

# Force exit on errors.
set -e

# generic-tests
uname -a
./error_test
./pcm_test
./ulaw_test
./alaw_test
./dwvw_test
./command_test ver
./command_test norm
./command_test format
./command_test peak
./command_test trunc
./command_test inst
./command_test current_sf_info
./command_test bext
./command_test bextch
./floating_point_test
./checksum_test
./scale_clip_test
./headerless_test
./locale_test
./win32_ordinal_test
./external_libs_test
./cpp_test
echo "----------------------------------------------------------------------"
echo "  $sfversion passed common tests."
echo "----------------------------------------------------------------------"

# aiff-tests
./write_read_test aiff
./lossy_comp_test aiff_ulaw
./lossy_comp_test aiff_alaw
./lossy_comp_test aiff_gsm610
echo "=========================="
echo "./lossy_comp_test aiff_ima"
echo "=========================="
./peak_chunk_test aiff
./header_test aiff
./misc_test aiff
./string_test aiff
./multi_file_test aiff
./aiff_rw_test
echo "----------------------------------------------------------------------"
echo "  $sfversion passed tests on AIFF files."
echo "----------------------------------------------------------------------"

# au-tests
./write_read_test au
./lossy_comp_test au_ulaw
./lossy_comp_test au_alaw
./lossy_comp_test au_g721
./lossy_comp_test au_g723
./header_test au
./misc_test au
./multi_file_test au
echo "----------------------------------------------------------------------"
echo "  $sfversion passed tests on AU files."
echo "----------------------------------------------------------------------"

# caf-tests
./write_read_test caf
./lossy_comp_test caf_ulaw
./lossy_comp_test caf_alaw
./header_test caf
./misc_test caf
echo "----------------------------------------------------------------------"
echo "  $sfversion passed tests on CAF files."
echo "----------------------------------------------------------------------"

# wav-tests
./write_read_test wav
./lossy_comp_test wav_pcm
./lossy_comp_test wav_ima
./lossy_comp_test wav_msadpcm
./lossy_comp_test wav_ulaw
./lossy_comp_test wav_alaw
./lossy_comp_test wav_gsm610
./lossy_comp_test wav_g721
./peak_chunk_test wav
./header_test wav
./misc_test wav
./string_test wav
./multi_file_test wav
echo "----------------------------------------------------------------------"
echo "  $sfversion passed tests on WAV files."
echo "----------------------------------------------------------------------"

# w64-tests
./write_read_test w64
./lossy_comp_test w64_ima
./lossy_comp_test w64_msadpcm
./lossy_comp_test w64_ulaw
./lossy_comp_test w64_alaw
./lossy_comp_test w64_gsm610
./header_test w64
./misc_test w64
echo "----------------------------------------------------------------------"
echo "  $sfversion passed tests on W64 files."
echo "----------------------------------------------------------------------"

# rf64-tests
./write_read_test rf64
./header_test rf64
./misc_test rf64
echo "----------------------------------------------------------------------"
echo "  $sfversion passed tests on RF64 files."
echo "----------------------------------------------------------------------"

# raw-tests
./write_read_test raw
./lossy_comp_test raw_ulaw
./lossy_comp_test raw_alaw
./lossy_comp_test raw_gsm610
./lossy_comp_test vox_adpcm
./raw_test
echo "----------------------------------------------------------------------"
echo "  $sfversion passed tests on RAW (header-less) files."
echo "----------------------------------------------------------------------"

# paf-tests
./write_read_test paf
./header_test paf
./misc_test paf
echo "----------------------------------------------------------------------"
echo "  $sfversion passed tests on PAF files."
echo "----------------------------------------------------------------------"

# svx-tests
./write_read_test svx
./header_test svx
./misc_test svx
echo "----------------------------------------------------------------------"
echo "  $sfversion passed tests on SVX files."
echo "----------------------------------------------------------------------"

# nist-tests
./write_read_test nist
./lossy_comp_test nist_ulaw
./lossy_comp_test nist_alaw
./header_test nist
./misc_test nist
echo "----------------------------------------------------------------------"
echo "  $sfversion passed tests on NIST files."
echo "----------------------------------------------------------------------"

# ircam-tests
./write_read_test ircam
./lossy_comp_test ircam_ulaw
./lossy_comp_test ircam_alaw
./header_test ircam
./misc_test ircam
echo "----------------------------------------------------------------------"
echo "  $sfversion passed tests on IRCAM files."
echo "----------------------------------------------------------------------"

# voc-tests
./write_read_test voc
./lossy_comp_test voc_ulaw
./lossy_comp_test voc_alaw
./header_test voc
./misc_test voc
echo "----------------------------------------------------------------------"
echo "  $sfversion passed tests on VOC files."
echo "----------------------------------------------------------------------"

# mat4-tests
./write_read_test mat4
./header_test mat4
./misc_test mat4
echo "----------------------------------------------------------------------"
echo "  $sfversion passed tests on MAT4 files."
echo "----------------------------------------------------------------------"

# mat5-tests
./write_read_test mat5
./header_test mat5
./misc_test mat5
echo "----------------------------------------------------------------------"
echo "  $sfversion passed tests on MAT5 files."
echo "----------------------------------------------------------------------"

# pvf-tests
./write_read_test pvf
./header_test pvf
./misc_test pvf
echo "----------------------------------------------------------------------"
echo "  $sfversion passed tests on PVF files."
echo "----------------------------------------------------------------------"

# xi-tests
./lossy_comp_test xi_dpcm
echo "----------------------------------------------------------------------"
echo "  $sfversion passed tests on XI files."
echo "----------------------------------------------------------------------"

# htk-tests
./write_read_test htk
./header_test htk
./misc_test htk
echo "----------------------------------------------------------------------"
echo "  $sfversion passed tests on HTK files."
echo "----------------------------------------------------------------------"

# avr-tests
./write_read_test avr
./header_test avr
./misc_test avr
echo "----------------------------------------------------------------------"
echo "  $sfversion passed tests on AVR files."
echo "----------------------------------------------------------------------"

# sds-tests
./write_read_test sds
./header_test sds
./misc_test sds
echo "----------------------------------------------------------------------"
echo "  $sfversion passed tests on SDS files."
echo "----------------------------------------------------------------------"

# sd2-tests
./write_read_test sd2
echo "----------------------------------------------------------------------"
echo "  $sfversion passed tests on SD2 files."
echo "----------------------------------------------------------------------"

# wve-tests
./lossy_comp_test wve
echo "----------------------------------------------------------------------"
echo "  $sfversion passed tests on WVE files."
echo "----------------------------------------------------------------------"

# mpc2k-tests
./write_read_test mpc2k
./header_test mpc2k
./misc_test mpc2k
echo "----------------------------------------------------------------------"
echo "  $sfversion passed tests on MPC 2000 files."
echo "----------------------------------------------------------------------"

# flac-tests
./write_read_test flac
./string_test flac
echo "----------------------------------------------------------------------"
echo "  $sfversion passed tests on FLAC files."
echo "----------------------------------------------------------------------"

# vorbis-tests
./ogg_test
./vorbis_test
./lossy_comp_test ogg_vorbis
./string_test ogg
./misc_test ogg
echo "----------------------------------------------------------------------"
echo "  $sfversion passed tests on OGG/VORBIS files."
echo "----------------------------------------------------------------------"

# io-tests
./stdio_test
./pipe_test
./virtual_io_test
echo "----------------------------------------------------------------------"
echo "  $sfversion passed stdio/pipe/vio tests."
echo "----------------------------------------------------------------------"


