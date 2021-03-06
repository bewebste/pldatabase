/*
 * Copyright (c) 2008 Plausible Labs Cooperative, Inc.
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 * 3. Neither the name of the copyright holder nor the names of any contributors
 *    may be used to endorse or promote products derived from this
 *    software without specific prior written permission.
 * 
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
 * AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
 * LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 * CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 * CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 * POSSIBILITY OF SUCH DAMAGE.
 */

#import <Foundation/Foundation.h>
#import "PLDatabase.h"

/**
 * Manages the database migration version. The version may be stored using
 * any method.
 *
 * @par Thread Safety
 * Thread-safe. May be used from any thread.
 *
 * @par Implementation Notes
 * Implementations must be immutable and/or thread-safe, and must be usable from any thread without external
 * locking.
 */
@protocol PLDatabaseMigrationVersionManager <NSObject>

/**
 * Retrieve the database's migration version, returning YES on success, or NO on failure. If the
 * database version is uninitialized, a value of 0 must be provided. This method may also
 * perform any necessary initialization of versioning meta-data tables.
 *
 * @param version A pointer to an NSInteger variable where the current migration version
 * will be stored on success.
 * @param database An active database connection on which to issue any queries.
 * @param outError A pointer to an NSError object variable. If an error occurs, this
 * pointer will contain an error object indicating why the version could not be retrieved.
 * If no error occurs, this parameter will be left unmodified. You may specify NULL for this
 * parameter, and no error information will be provided.
 */
- (BOOL) version: (int *) version forDatabase: (id<PLDatabase>) database error: (NSError **) outError;

/**
 * Set the database's migration version, returning YES on success, or NO on failure.
 *
 * A transaction will be opened prior to this method being called. The transaction will
 * be committed upon the return of a success value (YES). If this method returns NO,
 * the entire transaction will be aborted, and no changes made to the database.
 *
 * @param version The new migration version.
 * @param database An active database connection on which to issue any queries.
 * @param outError A pointer to an NSError object variable. If an error occurs, this
 * pointer will contain an error object indicating why the version could not be retrieved.
 * If no error occurs, this parameter will be left unmodified. You may specify NULL for this
 * parameter, and no error information will be provided.
 */
- (BOOL) setVersion: (int) version forDatabase: (id<PLDatabase>) database error: (NSError **) outError;

@end
