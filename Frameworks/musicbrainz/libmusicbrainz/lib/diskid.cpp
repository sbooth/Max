/* --------------------------------------------------------------------------

   MusicBrainz -- The Internet music metadatabase

   Copyright (C) 2000 Robert Kaye
   Copyright (C) 1999 Marc E E van Woerkom
   
   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Lesser General Public
   License as published by the Free Software Foundation; either
   version 2.1 of the License, or (at your option) any later version.
   
   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Lesser General Public License for more details.
   
   You should have received a copy of the GNU Lesser General Public
   License along with this library; if not, write to the Free Software
   Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA

     $Id: diskid.cpp 551 2003-01-22 01:47:05Z robert $

----------------------------------------------------------------------------*/
#include <assert.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <string>

#include "types.h"
#include "errors.h"
#include "diskid.h"

extern "C"
{
   #include "sha1.h"
   #include "base64.h"
}

DiskId::DiskId(void)
{
}

DiskId::~DiskId(void)
{
}

void DiskId::ReportError(char *err)
{
   m_errorMsg = string(err);
}

void DiskId::GetLastError(string &err)
{
   err = m_errorMsg;
}

void DiskId::TestGenerateId()
{
   SHA_INFO       sha;
   unsigned char  digest[20], *base64;
   unsigned long  size;

   sha_init(&sha);
   sha_update(&sha, (unsigned char *)"0123456789", 10);
   sha_final(digest, &sha);

   base64 = rfc822_binary(digest, 20, &size);
   if (strncmp((char*) base64, "h6zsF82dzSCnFsws9nQXtxyKcBY-", size))
   {
       free(base64);

       printf("The SHA-1 hash function failed to properly generate the\n");
       printf("test key.\n");
       exit(0);
   }
   free(base64);
}

void DiskId::GenerateId(PMUSICBRAINZ_CDINFO pCDInfo, 
                        char DiscId[33])
{
   SHA_INFO       sha;
   unsigned char  digest[20], *base64;
   unsigned long  size;
   char           temp[9];
   int            i;

   sha_init(&sha);

   // Before we ran the hash on the binary data, but now to make
   // sure people on both types of endian systems create the same
   // keys, we convert the data to hex-ASCII first. :-)
   sprintf(temp, "%02X", pCDInfo->FirstTrack);
   sha_update(&sha, (unsigned char *)temp, strlen(temp));

   sprintf(temp, "%02X", pCDInfo->LastTrack);
   sha_update(&sha, (unsigned char *)temp, strlen(temp));

   for(i = 0; i < 100; i++)
   {
       sprintf(temp, "%08lX", pCDInfo->FrameOffset[i]);
       sha_update(&sha, (unsigned char *)temp, strlen(temp));
   }
   sha_final(digest, &sha);

   base64 = rfc822_binary(digest, 20, &size);
   memcpy(DiscId, base64, size);
   DiscId[size] = 0;
   free(base64);
}

const string &DiskId::MakeString(int i)
{
   char   text[100];

   sprintf(text, "%d", i);
   
   return *new string(text);
}

Error DiskId::FillCDInfo(const string &device, MUSICBRAINZ_CDINFO &cdinfo)
{
   int   i;
   bool  bRet;

   // check SHA-1 sanity
   TestGenerateId();

   // clear cdinfo structure
   cdinfo.FirstTrack = 0;
   cdinfo.LastTrack = 0;
   
   for (i=0; i<100; i++)
       cdinfo.FrameOffset[i] = 0;

   if (device.length() == 0)
      bRet = ReadTOC(NULL, cdinfo);
   else
      bRet = ReadTOC((char *)device.c_str(), cdinfo);
   if (!bRet)
   {
       return kError_ReadTOCError;
   }

   return kError_NoErr;
}

Error DiskId::GenerateDiskIdRDF(const string &device, string &xml)
{
   MUSICBRAINZ_CDINFO cdinfo;
   int   i;
   char  id[33];
   Error eRet;

   eRet = FillCDInfo(device, cdinfo);
   if (IsError(eRet))
      return eRet;

   GenerateId(&cdinfo, id);

   xml = string("  <mq:Result>\n");
   xml += string("    <mq:status>OK</mq:status>\n");
   xml += string("    <mm:cdindexid>") + string(id) + 
          string("</mm:cdindexid>\n");
   xml += string("    <mm:firstTrack>") + 
          MakeString(cdinfo.FirstTrack) +
          string("</mm:firstTrack>\n");
   xml += string("    <mm:lastTrack>") + 
          MakeString(cdinfo.LastTrack) +
          string("</mm:lastTrack>\n");
   xml += string("    <mm:toc>\n      <rdf:Seq>\n");

   xml += string("       <rdf:li>\n");
   xml += string("         <mm:TocInfo>\n");
   xml += string("           <mm:sectorOffset>");
   xml += MakeString(cdinfo.FrameOffset[0]) +
          string("</mm:sectorOffset>\n");
   xml += string("           <mm:numSectors>0</mm:numSectors>\n");
   xml += string("         </mm:TocInfo>\n");
   xml += string("       </rdf:li>\n");

   for (i = cdinfo.FirstTrack; i <= cdinfo.LastTrack; i++)
   {
       xml += string("       <rdf:li>\n");
       xml += string("         <mm:TocInfo>\n");
       xml += string("           <mm:sectorOffset>") + 
              MakeString(cdinfo.FrameOffset[i]) +
              string("</mm:sectorOffset>\n");
       xml += string("           <mm:numSectors>");
       if (i < cdinfo.LastTrack)
       {
          xml += MakeString(cdinfo.FrameOffset[i + 1] - cdinfo.FrameOffset[i]);
       }
       else
       {
          xml += MakeString(cdinfo.FrameOffset[0] - cdinfo.FrameOffset[i]);
       }
       xml += string("</mm:numSectors>\n");
       xml += string("         </mm:TocInfo>\n");
       xml += string("       </rdf:li>\n");
   }

   xml += string("      </rdf:Seq>\n");
   xml += string("    </mm:toc>\n");
   xml += string("  </mq:Result>\n");

   return kError_NoErr;
}

Error DiskId::GenerateDiskIdQueryRDF(const string &device, string &xml,
                                     bool associateCD)
{
   MUSICBRAINZ_CDINFO cdinfo;
   int   i;
   char  id[33];
   Error eRet;

   eRet = FillCDInfo(device, cdinfo);
   if (IsError(eRet))
      return eRet;

   GenerateId(&cdinfo, id);

   if (associateCD)
       xml = string("  <mq:AssociateCD>\n");
   else
       xml = string("  <mq:GetCDInfo>\n");

   xml += string("  <mq:depth>@DEPTH@</mq:depth>\n");
   xml += string("    <mm:cdindexid>") + string(id) + 
          string("</mm:cdindexid>\n");
   if (associateCD)
      xml += string("    <mq:associate>@1@</mq:associate>\n");
   xml += string("    <mm:firstTrack>") + 
          MakeString(cdinfo.FirstTrack) +
          string("</mm:firstTrack>\n");
   xml += string("    <mm:lastTrack>") + 
          MakeString(cdinfo.LastTrack) +
          string("</mm:lastTrack>\n");
   xml += string("    <mm:toc>\n      <rdf:Seq>\n");

   xml += string("       <rdf:li>\n");
   xml += string("         <mm:TocInfo>\n");
   xml += string("           <mm:sectorOffset>");
   xml += MakeString(cdinfo.FrameOffset[0]) +
          string("</mm:sectorOffset>\n");
   xml += string("           <mm:numSectors>0</mm:numSectors>\n");
   xml += string("         </mm:TocInfo>\n");
   xml += string("       </rdf:li>\n");

   for (i = cdinfo.FirstTrack; i <= cdinfo.LastTrack; i++)
   {
       xml += string("       <rdf:li>\n");
       xml += string("         <mm:TocInfo>\n");
       xml += string("           <mm:sectorOffset>") + 
              MakeString(cdinfo.FrameOffset[i]) +
              string("</mm:sectorOffset>\n");
       xml += string("           <mm:numSectors>");
       if (i < cdinfo.LastTrack)
       {
          xml += MakeString(cdinfo.FrameOffset[i + 1] - cdinfo.FrameOffset[i]);
       }
       else
       {
          xml += MakeString(cdinfo.FrameOffset[0] - cdinfo.FrameOffset[i]);
       }
       xml += string("</mm:numSectors>\n");
       xml += string("         </mm:TocInfo>\n");
       xml += string("       </rdf:li>\n");
   }

   xml += string("      </rdf:Seq>\n");
   xml += string("    </mm:toc>\n");

   if (associateCD)
       xml += string("  </mq:AssociateCD>\n\n");
   else
       xml += string("  </mq:GetCDInfo>\n\n");

   return kError_NoErr;
}

Error DiskId::GetWebSubmitURLArgs(const string &device, string &args)
{
   MUSICBRAINZ_CDINFO cdinfo;
   int   i;
   char  id[33], toc_string[1024], tracks[10];
   Error eRet;

   eRet = FillCDInfo(device, cdinfo);
   if (IsError(eRet))
      return eRet;

   GenerateId(&cdinfo, id);

   // TO DO: resolve BeOS long issue
   sprintf(toc_string,
           "%d+%d+%d",
           (int)cdinfo.FirstTrack,
           (int)cdinfo.LastTrack,
           (int)cdinfo.FrameOffset[0]);

   for (i = cdinfo.FirstTrack; i <= cdinfo.LastTrack; i++)
   {
       sprintf(toc_string + strlen(toc_string),
               "+%d",
               (int)cdinfo.FrameOffset[i]);
   }   

   sprintf(tracks, "%d", cdinfo.LastTrack);
   args = string("?id=") + string(id) + string("&tracks=") + string(tracks);
   args += string("&toc=") + string(toc_string); 

   return kError_NoErr;
}
