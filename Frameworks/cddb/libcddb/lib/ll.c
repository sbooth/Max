/*
    $Id: ll.c,v 1.1 2005/05/29 08:24:05 airborne Exp $

    Copyright (C) 2005 Kris Verbeeck <airborne@advalvas.be>

    This library is free software; you can redistribute it and/or
    modify it under the terms of the GNU Library General Public
    License as published by the Free Software Foundation; either
    version 2 of the License, or (at your option) any later version.

    This library is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
    Library General Public License for more details.

    You should have received a copy of the GNU Library General Public
    License along with this library; if not, write to the
    Free Software Foundation, Inc., 59 Temple Place - Suite 330,
    Boston, MA  02111-1307, USA.
*/


#include <stdlib.h>

#include "cddb/ll.h"


/* --- type and structure definitions */


/**
 * Linked list element.
 */
struct elem_s {
    struct elem_s *prev;        /**< previous element */
    struct elem_s *next;        /**< next element  */
    void *data;                 /**< the actual data of the element */
};

struct list_s {
    int cnt;                    /**< number of elements in the list */
    elem_destroy_cb *free_data; /**< callback used to free element data */
    elem_t *first;              /**< the first element in the list  */
    elem_t *last;               /**< the last element in the list  */
    elem_t *it;                 /**< iterator element */
};


/* --- private prototypes */


static elem_t *elem_construct(void *data);

/**
 * @return The next element.
 */
static elem_t *elem_destroy(elem_t *elem, elem_destroy_cb *cb);


/* --- private functions */


static elem_t *elem_construct(void *data)
{
    elem_t *elem;

    elem = (elem_t*)calloc(1, sizeof(elem_t));
    elem->data = data;
    return elem;
}

static elem_t *elem_destroy(elem_t *elem, elem_destroy_cb *cb)
{
    elem_t *next = NULL;

    if (elem) {
        next = elem->next;
        if (cb) {
            cb(elem->data);
        }
        free(elem);
    }
    return next;
}


/* --- construction / destruction */


list_t *list_new(elem_destroy_cb *cb)
{
    list_t *list;

    list = (list_t*)calloc(1, sizeof(list_t));
    list->free_data = cb;
    return list;
}

void list_destroy(list_t *list)
{
    list_flush(list);
    if (list) {
        free(list);
    }
}

void list_flush(list_t *list)
{
    elem_t *elem;

    if (list) {
        elem = list->first;
        while (elem) {
            elem = elem_destroy(elem, list->free_data);
        }
        list->first = list->last = NULL;
        list->cnt = 0;
    }
}


/* --- list elements --- */


void *element_data(elem_t *elem)
{
    if (elem) {
        return elem->data;
    }
    return NULL;
}


/* --- getters & setters --- */


elem_t *list_append(list_t *list, void *data)
{
    elem_t *elem = NULL;

    if (list) {
        elem = elem_construct(data);
        if (elem) {
            if (list->cnt == 0) {
                list->first = list->last = elem;
            } else {
                list->last->next = elem;
                elem->prev = list->last;
                list->last = elem;
            }
            list->cnt++;
        }
    }
    return elem;
}

int list_size(list_t *list)
{
    if (list) {
        return list->cnt;
    }
    return 0;
}

elem_t *list_get(list_t *list, int idx)
{
    elem_t *elem = NULL;

    if (list) {
        if ((idx >= 0) && (idx < list->cnt)) {
            elem = list->first;
            while (idx) {
                elem = elem->next;
                idx--;
            }
        }
    }
    return elem;
}

elem_t *list_first(list_t *list)
{
    if (list) {
        list->it = list->first;
        return list->it;
    }
    return NULL;
}

elem_t *list_next(list_t *list)
{
    if (list) {
        if (list->it) {
            list->it = list->it->next;
        }
        return list->it;
    }
    return NULL;
}


/* --- iteration */
