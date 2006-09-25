/*
 * Copyright 2004 Jeremy Rossi <jeremy@jeremyrossi.com>
 * Released under the BSD license.
 */

#include <Python.h>
#import <Foundation/Foundation.h>
   

static PyObject *
growl_PostNotification(PyObject *self, PyObject *args)
{
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    char *name;
    char *key;
    const char *value;
    int i,j, size;

    PyObject *inputDict;
    PyObject *pKeys = NULL, *pKey,*pValue;

    NSString *noteName;
    NSString *convertedKey;
    NSString *convertedValue;
    NSString *convertedSubValue;
    NSData *convertedIcon;

    NSMutableDictionary *note = [NSMutableDictionary dictionary];

    NSMutableArray *listHolder = [NSMutableArray array];


    if (!PyArg_ParseTuple(args, "sO!", &name, &PyDict_Type, &inputDict)) {
        goto error;
    }
    noteName = [NSString stringWithUTF8String:name];
    

    pKeys = PyDict_Keys(inputDict);
    for(i = 0; i < PyList_Size(pKeys); ++i) {
        /* Converting the PyDict key to NSString and used for key in note */
        pKey = PyList_GetItem(pKeys, i);
        if (pKey == NULL) {
            // Exception already set
            goto error;
        }
        pValue = PyDict_GetItem(inputDict, pKey);
        if (pValue == NULL) {
            // XXX Neeed a real Error message here.
            PyErr_SetString(PyExc_TypeError," "); 
            goto error;
        }
        if (PyUnicode_Check(pKey)) {
            size = PyUnicode_GET_DATA_SIZE(pKey);
            value = PyUnicode_AS_DATA(pKey);
            convertedKey = [[[NSString alloc] initWithBytes:value 
                                                     length:size 
                                                   encoding:NSUnicodeStringEncoding] autorelease];
        } else if (PyString_Check(pKey)) {
            key = PyString_AsString(pKey);
            convertedKey = [NSString stringWithUTF8String:key];
        } else {
            PyErr_SetString(PyExc_TypeError,"The Dict keys must be strings/unicode");
            goto error;
        }

        /* Converting the PyDict value to NSString or NSData based on class  */
        if (PyString_Check(pValue)) {
            [note setObject:[NSString stringWithUTF8String:PyString_AS_STRING(pValue)] forKey:convertedKey];
        } else if (PyUnicode_Check(pValue)) {
            convertedValue = [[[NSString alloc] initWithBytes:PyUnicode_AS_DATA(pValue)
                                                       length:PyUnicode_GET_DATA_SIZE(pValue)
                                                     encoding:NSUnicodeStringEncoding] autorelease];
            [note setObject:convertedValue forKey:convertedKey];
        } else if (pValue == Py_None) {
            [note setObject:[NSData data] forKey:convertedKey];
        } else if (PyList_Check(pValue)) {
            [listHolder removeAllObjects];
            for(j = 0; j < PyList_Size(pValue); ++j) {
                PyObject *lValue = PyList_GetItem(pValue, j);
                if (PyString_Check(lValue)) {
                    [listHolder  addObject:[NSString stringWithUTF8String:PyString_AS_STRING(lValue)]];
                } else if (PyUnicode_Check(lValue)) {
                    convertedSubValue = [[[NSString alloc] initWithBytes:PyUnicode_AS_DATA(pValue)
                                                                  length:PyUnicode_GET_DATA_SIZE(lValue)
                                                                encoding:NSUnicodeStringEncoding] autorelease];
                    [listHolder addObject:convertedSubValue];
                } else {
                    PyErr_SetString(PyExc_TypeError,"The lists must only contain strings");
                    goto error;
                }
            }
            [note setObject:listHolder forKey:convertedKey];
        } else if (PyObject_HasAttrString(pValue, "rawImageData")) {
            PyObject *lValue = PyObject_GetAttrString(pValue, "rawImageData");
            if (! lValue) {
                goto error;
            } else if (PyString_Check(lValue)) {
                convertedIcon = [[[NSData alloc] initWithBytes:PyString_AsString(lValue)
                                                        length:PyString_Size(lValue)] autorelease];
                [note setObject:convertedIcon forKey:convertedKey];
            } else {
                PyErr_SetString(PyExc_TypeError, "Icon with rawImageData attribute present must ensure it is a string.");
                goto error;
            }
        } else {
            PyErr_SetString(PyExc_TypeError, "Value is not of Str/List");
            goto error;
        }
    }

    Py_BEGIN_ALLOW_THREADS
    [[NSDistributedNotificationCenter defaultCenter] postNotificationName:noteName
                                                                   object:nil 
                                                                 userInfo:note
                                                       deliverImmediately:YES];

    [pool release];
    Py_END_ALLOW_THREADS
    
    Py_DECREF(pKeys);
    
    Py_INCREF(Py_None);
    return Py_None;

error:
    [pool release];

    Py_XDECREF(pKeys);

    return NULL;
}


static PyMethodDef GrowlMethods[] = {
    {"PostNotification",  growl_PostNotification, METH_VARARGS, "Send a Notify to GrowlAppHelper"},
    {NULL, NULL, 0, NULL}        /* Sentinel */
};



PyMODINIT_FUNC
init_growl(void)
{
    (void) Py_InitModule("_growl", GrowlMethods);
}

