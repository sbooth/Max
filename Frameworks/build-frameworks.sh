#!/bin/bash

##
 #  $Id$
 #
 #  Copyright (C) 2005, 2006 Stephen F. Booth <me@sbooth.org>
 #
 #  This program is free software; you can redistribute it and/or modify
 #  it under the terms of the GNU General Public License as published by
 #  the Free Software Foundation; either version 2 of the License, or
 #  (at your option) any later version.
 #
 #  This program is distributed in the hope that it will be useful,
 #  but WITHOUT ANY WARRANTY; without even the implied warranty of
 #  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 #  GNU General Public License for more details.
 #
 #  You should have received a copy of the GNU General Public License
 #  along with this program; if not, write to the Free Software
 #  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
 ##

## Save the current directory
WD=`pwd`

## Sparkle framework
cd Sparkle && \
	xcodebuild \
		-project Sparkle.xcodeproj \
		-target Sparkle \
		-configuration Release \
	&& cd $WD
		
## Growl framework
cd Growl && \
	xcodebuild \
		-project Growl.xcodeproj \
		-target Growl.framework \
		-configuration Deployment \
	&& cd $WD

## ogg framework
cd ogg && \
	xcodebuild \
		-project ogg.xcodeproj \
		-target ogg.framework \
		-configuration Release \
	&& cd $WD

## vorbis framework
cd vorbis && \
	xcodebuild \
		-project vorbis.xcodeproj \
		-target vorbis.framework \
		-configuration Release \
	&& cd $WD

## LAME framework
cd lame && \
	xcodebuild \
		-project lame.xcodeproj \
		-target lame.framework \
		-configuration Release \
	&& cd $WD

## wavpack framework
cd wavpack && \
	xcodebuild \
		-project wavpack.xcodeproj \
		-target wavpack.framework \
		-configuration Release \
	&& cd $WD

## speex framework
cd speex && \
	xcodebuild \
		-project speex.xcodeproj \
		-target speex.framework \
		-configuration Release \
	&& cd $WD

## FLAC framework
cd flac && \
	xcodebuild \
		-project flac.xcodeproj \
		-target FLAC.framework \
		-configuration Release \
	&& cd $WD

## OggFLAC framework
cd flac && \
	xcodebuild \
		-project flac.xcodeproj \
		-target OggFLAC.framework \
		-configuration Release \
	&& cd $WD

## taglib framework
cd taglib && \
	xcodebuild \
		-project taglib.xcodeproj \
		-target taglib.framework \
		-configuration Release \
	&& cd $WD

## mac framework
cd mac && \
	xcodebuild \
		-project mac.xcodeproj \
		-target mac.framework \
		-configuration Release \
	&& cd $WD

## sndfile framework
cd sndfile && \
	xcodebuild \
		-project sndfile.xcodeproj \
		-target sndfile.framework \
		-configuration Release \
	&& cd $WD

## mpcdec framework
cd mpcdec && \
	xcodebuild \
		-project mpcdec.xcodeproj \
		-target mpcdec.framework \
		-configuration Release \
	&& cd $WD

## cuetools framework
cd cuetools && \
	xcodebuild \
		-project cuetools.xcodeproj \
		-target cuetools.framework \
		-configuration Release \
	&& cd $WD
