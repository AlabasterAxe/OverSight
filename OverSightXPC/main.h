//
//  main.h
//  OverSight
//
//  Created by Patrick Wardle on 9/16/16.
//  Copyright (c) 2016 Objective-See. All rights reserved.
//

#ifndef main_h
#define main_h

#import <bsm/libbsm.h>
#import <Foundation/Foundation.h>

#import "Logging.h"
#import "Exception.h"
#import "XPCProtocol.h"
#import "OverSightXPC.h"


/* GLOBALS */

//client/requestor pid
extern pid_t clientPID;

/* FUNCTION DEFINITIONS */

OSStatus SecTaskValidateForRequirement(SecTaskRef task, CFStringRef requirement);

/* #DEFINES */

//signing auth
#define SIGNING_AUTH @"Developer ID Application: Objective-See, LLC (VBG97UB4TA)"

/* INTERFACES */

//interface for 'extension' to NSXPCConnection
// ->allows us to access the 'private' auditToken iVar
@interface ExtendedNSXPCConnection : NSXPCConnection
{
    //private iVar
    audit_token_t auditToken;
}
//private iVar
@property audit_token_t auditToken;

@end

//skeleton interface
@interface ServiceDelegate : NSObject <NSXPCListenerDelegate>
@end


#endif /* main_h */
