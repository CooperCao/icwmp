/*
 *	This program is free software: you can redistribute it and/or modify
 *	it under the terms of the GNU General Public License as published by
 *	the Free Software Foundation, either version 2 of the License, or
 *	(at your option) any later version.
 *	Powered by Inteno Broadband Technology AB
 *
 *	Copyright (C) 2013 Mohamed Kallel <mohamed.kallel@pivasoftware.com>
 *	Copyright (C) 2013 Ahmed Zribi <ahmed.zribi@pivasoftware.com>
 *
 */

#ifndef _JSHN_H__
#define _JSHN_H__

int cwmp_handle_downloadFault(char *msg);
int cwmp_handle_getParamValues(char *msg);
int cwmp_handle_setParamValues(char *msg);
int cwmp_handle_getParamNames(char *msg);
int cwmp_handle_getParamAttributes(char *msg);
int cwmp_handle_setParamAttributes(char *msg);
int cwmp_handle_addObject(char *msg);
int cwmp_handle_delObject(char *msg);

#endif /* _JSHN_H__ */