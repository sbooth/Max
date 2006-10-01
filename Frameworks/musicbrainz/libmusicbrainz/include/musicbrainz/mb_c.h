/* --------------------------------------------------------------------------

   MusicBrainz -- The Internet music metadatabase

   Copyright (C) 2000 Robert Kaye
   
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

     $Id: mb_c.h 773 2005-11-15 02:43:37Z robert $

----------------------------------------------------------------------------*/
#ifndef _MB_C_H_
#define _MB_C_H_

#include "errors.h"
#include "queries.h"

#ifdef __cplusplus
extern "C"
{
#endif

/**
 * The length of a CD Index id in characters
 */
#define MB_CDINDEX_ID_LEN 28

/**
 * The length of a Artist/Album/Track id in characters
 */
#define MB_ID_LEN 36

/**
 * Basic C abstraction for the MusicBrainz Object 
 */
typedef void * musicbrainz_t;
/**
 * Basic C abstraction for the TRM Object 
 */
typedef void * trm_t;

/**
 * Create a new handle (a C abstraction) to the MusicBrainz object.
 * Call mb_Delete() when done with the handle.
 * @see mb_Delete()
 * @return the musicbrainz_t type is used in subsequent musicbrainz functions.
 */
musicbrainz_t mb_New           (void);

/**
 * The destructor for the MusicBrainz class.
 * @see mb_New()
 * @param o the musicbrainz_t object to delete
 */
void      mb_Delete            (musicbrainz_t o);

/**
 * Get the version number of this library
 * @param o the musicbrainz_t object returned from mb_New
 * @param major an int pointer that will receive the major number of the version
 * @param minor an int pointer that will receive the minor number
 * @param rev   an int pointer that will receive the rev number
 */
void      mb_GetVersion        (musicbrainz_t o, int *major, int *minor,
                                int *rev);

/**
 * Set the name and the port of the MusicBrainz server to use. If this
 * function is not called, the default www.musicbrainz.org server on port
 * 80 will be used.
 * @see mb_SetProxy
 * @param o the musicbrainz_t object returned from mb_New
 * @param serverAddr the name of the musicbrainz server to use 
 *                   e.g. www.musicbrainz.org
 * @param serverPort the port number to use. e.g. 80
 */
int       mb_SetServer         (musicbrainz_t o, char *serverAddr, 
                                short serverPort);

/**
 * Enable debug out to stdout by sending a non-zero value to this
 * function. 
 * @param o the musicbrainz_t object returned from mb_New
 * @param debug whether or not to enable debug (non zero enables debug output)
 */
void       mb_SetDebug         (musicbrainz_t o, int debug);

/**
 * Set the name of the HTTP Proxy to use. This function must be called anytime
 * the client library must communicate via a proxy firewall. 
 * @see  mb_SetServer
 * @param o the musicbrainz_t object returned from mb_New()
 * @param serverAddr the name of the proxy server to use 
 *                   e.g. proxy.mydomain.com
 * @param serverPort the port number to use. e.g. 8080
 */
int       mb_SetProxy          (musicbrainz_t o, char *serverAddr, 
                                short serverPort);
#ifdef WIN32
/**
 * WINDOWS ONLY: This function must be called to initialize the WinSock
 * TCP/IP stack in windows. If your application does not utilize any
 * WinSock functions, you must call this function before you can call
 * mb_Query(). Before your application shuts down, you must call mb_WSAStop().
 * If you already call WSAInit from your own application,
 * you do not need to call this function.
 * @see mb_WSAStop.
 * @param o the musicbrainz_t object returned from mb_New()
 */
void      mb_WSAInit           (musicbrainz_t o);

/**
 * WINDOWS ONLY: Call this function when your application shuts down. Only
 * call this function if you called mb_WSAInit().
 * @see mb_WSAInit
 * @param o the musicbrainz_t object returned from mb_New()
 * @param
 */
void      mb_WSAStop           (musicbrainz_t o);
#endif 

/**
 * This function must be called if you want to submit data to the server
 * and give the user credit for the submission. If you're looking up
 * data from the server, you do not need to call mb_Authenticate.
 * If you are submitting data to the MB server and you want your submissions
 * be submitted anonymously, then do not call this function.
 * @param o the musicbrainz_t object returned from mb_New()
 * @param userName the name of the user
 * @param password the plaintext password of the user.
 * @return returns true if the server authentication was correctly
 *         initiated.
 */
int mb_Authenticate(musicbrainz_t o, char *userName, char *password);

/**
 * Call this function to set the CD-ROM drive device if you plan to use
 * the client library to identify and look up CD-ROMs using MusicBrainz.
 * @a Unix: specify a device such as /dev/cdrom. Defaults to /dev/cdrom
 * @a Windows: specify a drive letter of a CD-ROM drive. e.g. E: 
 * @param o the musicbrainz_t object returned from mb_New()
 * @param device see above
 * @return always returns true. :-)
 */
int       mb_SetDevice         (musicbrainz_t o, char *device);

/**
 * Use this function to set the output returned by the Get function. The
 * Get functions can return data in ISO-8859-1 encoding or in UTF-8.
 * Defaults to ISO-8859-1.
 * @see 
 * @param o the musicbrainz_t object returned from mb_New()
 * @param useUTF8 if set to a non-zero value, UTF-8 will be used.
 */
void      mb_UseUTF8           (musicbrainz_t o, int useUTF8);

/**
 * Set the search depth of the query. Please refer to the MusicBrainz HOWTO
 * for an explanation of this value. Defaults to 2.
 * @see mb_Query()
 * @param o the musicbrainz_t object returned from mb_New()
 * @param depth an integer value from zero or greater
 */
void      mb_SetDepth          (musicbrainz_t o, int depth);

/**
 * Set the maximum number of items to return to the client. If a search
 * query yields more items than this max number, the server will omit
 * the excess items and not return them to the client. This value defaults
 * to 25.
 * @see mb_Query()
 * @param o the musicbrainz_t object returned from mb_New()
 * @param maxItems the maximum number of items to return for a search 
 */
void      mb_SetMaxItems       (musicbrainz_t o, int maxItems);

/**
 * Query the MusicBrainz server. Use this function if your query requires no
 * arguments other than the query itself. Please refer to the HOWTO for
 * the documentation on the available queries.
 * @see mb_GetQueryError mb_QueryWithArgs
 * @param o the musicbrainz_t object returned from mb_New()
 * @param rdfObject the query to execute. See the HOWTO for details.
 * @return true if the query succeeded (even if no items are returned) and
 *         false if the query failed. Call mb_GetQueryError() for details
 *         on the error that occurred.
 */
int       mb_Query             (musicbrainz_t o, char *rdfObject);

/**
 * Query the MusicBrainz server. Use this function if your query requires one 
 * or more arguments. The arguments are specified via a pointer to an array
 * of char *. To pass two arguments to the mb_QueryWithArgs() call, do this
 * <PRE> 
 *    char *args[3];
 *    args[0] = "Portishead";
 *    args[1] = "Dummy";
 *    args[3] = NULL;
 *    mb_QueryWithArgs(MBQ_AlbumFindAlbum, args);
 * </PRE>
 * Note that the last element in the args array must point to NULL, to prevent
 * the client library from crashing should an incorrect number of arguments
 * be specified for the given query. Please refer to the HOWTO for the 
 * documentation on the available queries and the number of required arguments
 * @see mb_GetQueryError mb_Query
 * @param o the musicbrainz_t object returned from mb_New()
 * @param rdfObject the query to execute. See the HOWTO for details.
 * @param args The array of character pointers that contain the arguments.
 * @return true if the query succeeded (even if no items are returned) and
 *         false if the query failed. Call mb_GetQueryError() for details
 *         on the error that occurred.
 */
int       mb_QueryWithArgs     (musicbrainz_t o, char *rdfObject, char **args);

/**
 * Use this function to query the current CD-ROM and to calculate the
 * web submit URL that can be opened in a browser in order to start
 * the web based CD-ROM Submission to MusicBrainz. The CD-ROM in the CD-ROM 
 * drive set by mb_SetDevice() will be queried.
 * @see mb_SetDevice
 * @param o the musicbrainz_t object returned from mb_New()
 * @param url the location where the url will be stored.
 * @param urlLen the length of the url field.
 * @return true if the url was successfully generated, false if an error 
 *         occurred.
 */
int       mb_GetWebSubmitURL   (musicbrainz_t o, char *url, int urlLen);

/**
 * Retrieve the error message that was generated during the last call to
 * mb_Query() or mb_QueryWithArgs().
 * @see mb_Query mb_QueryWithArgs
 * @param o the musicbrainz_t object returned from mb_New()
 * @param error the location where the error message will be written
 * @param errorLen the length of the error location
 */
void      mb_GetQueryError     (musicbrainz_t o, char *error, int errorLen);

/**
 * Select a context in the result query. Use this function if your Select
 * requires no ordinal arguments. Pass this function a select query (starts
 * with MBS_) Please refer to the MusicBrainz HOWTO
 * for more details on why you need to do a Select and what types of Selects
 * are available.
 * @see mb_Select1, mb_SelectWithArgs
 * @param o the musicbrainz_t object returned from mb_New()
 * @param selectQuery The select query as outlined in the MusicBrainz HOWTO.
 * @return true if the select succeeded, false otherwise.
 */
int       mb_Select            (musicbrainz_t o, char *selectQuery);

/**
 * Select a context in the result query. Use this function if your Select
 * requires one ordinal argument. Pass this function a selectQuery
 * (usually start with MBS_) as defined in the MusicBrainz HOWTO. See the
 * HOWTO for more details on why you need to do a Select and what types of 
 * Selects are available.
 * @see mb_Select, mb_SelectWithArgs
 * @param o the musicbrainz_t object returned from mb_New()
 * @param selectQuery The select query as outlined in the MusicBrainz HOWTO.
 * @param ord The ordinal as used to select items in a list.
 * @return true if the select succeeded, false otherwise.
 */
int       mb_Select1           (musicbrainz_t o, char *selectQuery, int ord);

/**
 * Select a context in the result query. Use this function if your Select
 * requires more than one ordinal argument. Pass this function a selectQuery
 * (usually start with MBS_) as defined in the MusicBrainz HOWTO. 
 * The ordinal arguments are passed
 * in an array of ints, with the last int being a zero:
 * <PRE> 
 *    int ordinals[3];
 *    ordinals[0] = 2;
 *    ordinals[1] = 3;
 *    ordinals[3] = 0;
 *    mb_QueryWithArgs(MBQ_AlbumFindAlbum, ordinals);
 * </PRE>
 * Note that the last element in the ordinals array must be 0.
 * be specified for the given query. Please refer to the HOWTO for the 
 * Please refer to the MusicBrainz HOWTO for more details on why you need to 
 * do a Select and what types of Selects are available.
 * @see mb_QueryWithArgs, mb_Select, mb_Select1
 * @param o the musicbrainz_t object returned from mb_New()
 * @param selectQuery The select query as outlined in the MusicBrainz HOWTO.
 * @param ordinals The array of character pointers that contain the arguments.
 * @return true if the select succeeded, false otherwise.
 */
int       mb_SelectWithArgs    (musicbrainz_t o, char *selectQuery, 
                                int *ordinals);

/**
 * Extract a piece of information from the data returned by a successful
 * query. This function takes a resultName (usually named starting with
 * MBE_), as defined in the MusicBrainz HOWTO.
 * @see mb_GetResultData1
 * @param o the musicbrainz_t object returned from mb_New()
 * @param resultName The name of the piece of data to query (MBE_)
 * @param data The place to store the extracted data
 * @param dataLen The number of bytes set aside in data
 * @return true if the correct piece of data was returned and found,
 *         false otherwise.
 */
int       mb_GetResultData     (musicbrainz_t o, char *resultName, 
                                char *data, int dataLen);
/**
 * Extract a piece of information from the data returned by a successful
 * query. This function takes a resultName (usually named starting with
 * MBE_), as defined in the MusicBrainz HOWTO, and on ordinal argument.
 * @see mb_GetResultData
 * @param o the musicbrainz_t object returned from mb_New()
 * @param resultName The name of the piece of data to query (MBE_)
 * @param data The place to store the extracted data
 * @param maxDataLen The number of bytes set aside in data
 * @param ordinal The ordinal required by the resultName. 
 * @return true if the correct piece of data was returned and found,
 *         false otherwise.
 */
int       mb_GetResultData1    (musicbrainz_t o, char *resultName, 
                                char *data, int maxDataLen, int ordinal);
/**
 * Check to see if a piece of information exists in data returned by a 
 * successful query. This function takes the same resultName argument
 * as mb_GetResultData()
 * @see mb_GetResultData
 * @param o the musicbrainz_t object returned from mb_New()
 * @param resultName The name of the piece of data to query (MBE_)
 * @return true if the result data exists, false otherwise
 */
int       mb_DoesResultExist   (musicbrainz_t o, char *resultName);
/**
 * Check to see if a piece of information exists in data returned by a 
 * successful query. This function takes the same resultName and ordinal 
 * arguments as mb_GetResultData1()
 * @see mb_GetResultData1
 * @param o the musicbrainz_t object returned from mb_New()
 * @param resultName The name of the piece of data to query (MBE_)
 * @param ordinal The ordinal required by the resultName. 
 * @return true if the result data exists, false otherwise
 */
int       mb_DoesResultExist1  (musicbrainz_t o, char *resultName, int ordinal);
/**
 * Return the integer value of a result from the data returned by a 
 * successful Query. This function takes the same resultName argument
 * as mb_GetResultData()
 * @see mb_GetResultData
 * @param o the musicbrainz_t object returned from mb_New()
 * @param resultName The name of the piece of data to query (MBE_)
 * @return the integer value of the result
 */
int       mb_GetResultInt      (musicbrainz_t o, char *resultName);
/**
 * Return the integer value of a result from the data returned by a 
 * successful query. This function takes the same resultName and ordinal 
 * arguments as mb_GetResultData1()
 * @see 
 * @param o the musicbrainz_t object returned from mb_New()
 * @param resultName The name of the piece of data to query (MBE_)
 * @param ordinal The ordinal required by the resultName. 
 * @return the integer value of the result
 */
int       mb_GetResultInt1     (musicbrainz_t o, char *resultName, int ordinal);

/**
 * Retrieve the RDF that was returned by the server. Most users will not
 * want to use this function!
 * @see mb_GetResultRDFLen
 * @param o the musicbrainz_t object returned from mb_New()
 * @param RDF a string where the rdf will be stored.
 * @param RDFLen the length of the string
 */
int       mb_GetResultRDF      (musicbrainz_t o, char *RDF, int RDFLen);

/**
 * Returns the length (in bytes) of the current RDF result. Advanced users
 * only!
 * @see mb_GetResultRDF
 * @param o the musicbrainz_t object returned from mb_New()
 * @return the size in bytes of the current RDF result.
 */
int       mb_GetResultRDFLen   (musicbrainz_t o);

/**
 * Set an RDF object for so that the Get functions can be used to
 * extract data from the RDF. Advanced users only!
 * @see mb_GetRDFResult
 * @param o the musicbrainz_t object returned from mb_New()
 * @param RDF A pointer to the RDF to set for extraction
 */
int       mb_SetResultRDF      (musicbrainz_t o, char *RDF);

/**
 * Extract the actual artist/album/track ID from a MBE_GETxxxxxId query.
 * The MBE_GETxxxxxId functions return a URL to where the more RDF metadata
 * for the given ID can be retrieved. Callers may wish to extract only the
 * ID of an artist/album/track for reference in elsewhere.
 * @see mb_GetResultData 
 * @param o the musicbrainz_t object returned from mb_New()
 * @param url the url returned from a mb_GetResultData call
 * @param id the location where the id will be stored
 * @param idLen the length of the id field. 64 characters should suffice.
 */
void      mb_GetIDFromURL      (musicbrainz_t o, char *url, char *id, 
                                int idLen);

/**
 * Extract the identifier fragment from a URI. Given a URI this function
 * will return the string that follows the # seperator. 
 * (e.g. when passed 'http://musicbrainz.org/mm/mq-1.1#ArtistResult', this
 * function will return 'ArtistResult'
 * @param o the musicbrainz_t object returned from mb_New()
 * @param url the url returned from a mb_GetResultData call
 * @param fragment the location where the fragment will be stored
 * @param fragmentLen the length of the id field.
 */
void      mb_GetFragmentFromURL(musicbrainz_t o, char *url, char *fragment, 
                                int fragmentLen);

/**
 * Get the ordinal (list position) of an item in a list. This function is
 * normally used to retrieve the track number out of a list of tracks in
 * an album using a list query (usually MBE_AlbumGetTrackList)
 * @see MBE_AlbumGetTrackList
 * @param o the musicbrainz_t object returned from mb_New()
 * @param listType (usually MBE_AlbumGetTrackList)
 * @param URI of the item from the list to return.
 */
int       mb_GetOrdinalFromList(musicbrainz_t o, char *listType, char *URI);

/**
 * This helper function calculates the crucial pieces of information for an MP3
 * files. This function returns the duration of the MP3 in milliseconds, which
 * is handy for passing the length of the track to the TRM generation routines.
 * Beware: The TRM routines are expecting the duratin in SECONDS, so you will
 *         need to divide the duration returned by this function by 1000 before
 *         you pass it to the TRM routines.
 * @param o the musicbrainz_t object returned from mb_New()
 * @param fileName the file to get mp3 info for
 * @param duration the duration of the mp3 filein milliseconds.
 * @param bitrate the bitrate of the mp3 file in kilobits/second
 * @param stereo true (1) if stereo false (0) otherwise.
 * @param samplerate the sample rate for this MP3 file.
 * @return true if the mp3 was successfully examined, false otherwise.
 *  */
int       mb_GetMP3Info        (musicbrainz_t  o, 
                                char          *fileName, 
                                int           *duration,
                                int           *bitrate,
                                int           *stereo,
                                int           *samplerate);

/* The interface to the Relatable TRM signature generator */

/**
 * The contructor for the TRM class.
 * Call trm_Delete() when done with the object.
 * @see trm_Delete()
 * @return the trm_t object used to refer to the class instance.
 */
trm_t trm_New                 (void);

/**
 * The destructor for the TRM class.
 * @see trm_New()
 * @param o the trm_t object to delete
 */
void  trm_Delete              (trm_t o);

/**
 * Called to set a proxy server to use for Internet access.
 * @param o the trm_t object returned by trm_New()
 * @param proxyAddr the name of the proxy server to use. eg. proxy.domain.com
 * @param proxyPort the port number that the proxy server uses. eg. 8080
 * @return 1 on success, 0 on failure
 */
int   trm_SetProxy            (trm_t o, char *proxyAddr, short proxyPort);

/**
 * Called to set the type of audio being sent to be signatured.
 * This MUST be called before attempting to generate a signature.
 * @see trm_GenerateSignature()
 * @see trm_GenerateSignatureNow()
 * @param o the trm_t object returned by trm_New()
 * @param samplesPerSecond the sampling rate of the audio. eg. 44100
 * @param numChannels the number of audio channels in the audio. 
 * must be 1 or 2 for mono or stereo respectively.
 * @param bitsPerSample the number of bits per audio sample.  must be 8 or 16.
 * @return 1 on success, 0 on failure
 */
int  trm_SetPCMDataInfo      (trm_t o, int samplesPerSecond, 
                               int numChannels, int bitsPerSample);

/**
 * Called to set the total length of the song in seconds.  Optional, but if this
 * function is not used, trm_GenerateSignature() will calculate the length of
 * the audio instead.  Must be called after trm_SetPCMDataInfo() but before
 * any calls to trm_GenerateSignature().
 * @see trm_SetPCMDataInfo()
 * @see trm_GenerateSignature()
 * @param o the trm_t object returned by trm_New()
 * @param seconds the total number of seconds of the track
 */
void  trm_SetSongLength(trm_t o, long int seconds);

/**
 * The main functionality of the TRM class.  Audio is passed to this function
 * and stored for analysis. trm_SetPCMDataInfo() needs to be called before
 * calling this function.  trm_FinalizeSignature() needs to be called after
 * this function has returned a '1' or there is no more audio data to be
 * passed in.
 * @see trm_SetPCMDataInfo()
 * @see trm_FinalizeSignature()
 * @see mb_WSAInit
 * @see mb_WSAStop
 * @param o the trm_t object returned by trm_New()
 * @param data a pointer to the block of audio data being sent to the function. 
 * It needs to be raw PCM data in the format specified by the call to 
 * trm_SetPCMDataInfo()
 * @param size the size in bytes of the data block.
 * @return returns 1 if enough data has been sent to generate a signature, 
 * or 0 if more data is still needed.  After it returns a '1',
 * trm_FinalizeSignature must be called.
 */
int   trm_GenerateSignature   (trm_t o, char *data, int size);

/**
 * Used when there is no more audio data available or trm_GenerateSignature() 
 * has returned a '1'.  This function finishes the  generation of a 
 * signature from the data already sent via trm_GenerateSignature().
 * This function will access the Relatable signature server to generate 
 * the signature itself. Windows only: You will need to call mb_WSAInit before 
 * you can use this function. If your program already uses sockets, you will 
 * not need to call WSAInit and WSAStop.
 * @see trm_SetPCMDataInfo()
 * @see trm_GenerateSignature()
 * @see mb_WSAInit
 * @see mb_WSAStop
 * @param o the trm_t object returned by trm_New()
 * @param signature a 17 character array to store the signature in.
 * @param collectionID an optional 16-byte string to associate the signature
 * with a particular collection in the Relatable Engine.  Generally, pass in 
 * NULL.
 * @return Returns 0 on success, -1 on failure
 */
int  trm_FinalizeSignature   (trm_t o, char signature[17], char *collectionID);

/**
 * This translates the 16 character raw signature into a 36 character 
 * human-readable string containing only letters and numbers.  Used after 
 * trm_GenerateSignature() or trm_GenerateSignatureNow() has generated a 
 * signature.
 * @param o the trm_t object returned by trm_New()
 * @param sig the raw 16 character signature returned by one of the Generate
 * functions.
 * @param ascii_sig the more human readable form of the signature.
 */
void  trm_ConvertSigToASCII   (trm_t o, char sig[17], 
                               char ascii_sig[37]);

#ifdef __cplusplus
}
#endif

#endif
