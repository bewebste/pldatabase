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

#import <SenTestingKit/SenTestingKit.h>

#import "PLSqliteDatabase.h"
#import "PLSqliteMigrationManager.h"
#import "PLDatabaseMigrationManager.h"

#define TEST_DATABASE_VERSION 42

@interface PLDatabaseMigrationManagerTests : SenTestCase {
@private
    NSString *_testDir;
    PLDatabaseMigrationManager *_dbManager;
    PLSqliteMigrationManager *_versionManager;
}

@end

@interface PLDatabaseMigrationManagerTestsDelegateMock : NSObject <PLDatabaseMigrationDelegate> {
@private
    int _newVersion;
    BOOL _shouldFail;
}
@end

@implementation PLDatabaseMigrationManagerTestsDelegateMock

- (id) initWithNewVersion: (int) newVersion shouldFail: (BOOL) shouldFail {
    if((self = [super init]) == nil)
        return nil;

    _newVersion = newVersion;
    _shouldFail = shouldFail;
    
    return self;
}

- (BOOL) migrateDatabase: (id<PLDatabase>) database 
          currentVersion: (int) currentVersion 
              newVersion: (int *) newVersion 
                   error: (NSError **) outError
{
    *newVersion = _newVersion;
    
    /* Create ourselves a table */
    if (![database executeUpdateAndReturnError: outError statement: @"CREATE TABLE testtable (string VARCHAR(50))"])
        return NO;

    if (_shouldFail) {
        if (outError != NULL)
            *outError = [NSError errorWithDomain: PLDatabaseErrorDomain code: PLDatabaseErrorUnknown userInfo: nil];
        return NO;
    } else {
        return YES;
    }
}

@end


@interface PLDatabaseMigrationManagerTestsDelegateDoNothingMock : NSObject <PLDatabaseMigrationDelegate> @end

/**
 * @internal
 * Migration delegate that does nothing, but returns success. Used to test whether the version
 * is set/reset/modified if the delegate fails to set the new version explicitly.
 */
@implementation PLDatabaseMigrationManagerTestsDelegateDoNothingMock

- (BOOL) migrateDatabase: (id<PLDatabase>) database 
          currentVersion: (int) currentVersion 
              newVersion: (int *) newVersion 
                   error: (NSError **) outError
{
    /* Do nothing */
    return YES;
}

@end



@implementation PLDatabaseMigrationManagerTests


- (void) setUp {
    /* Create a temporary directory. Secure, as the user owns enclosing directory. */
    _testDir = [[NSTemporaryDirectory() stringByAppendingPathComponent: [[NSProcessInfo processInfo] globallyUniqueString]] retain];
    STAssertTrue([[NSFileManager defaultManager] createDirectoryAtPath: _testDir withIntermediateDirectories: YES attributes: nil error: NULL],
                 @"Could not create test directory");
    
    /* A new database manager */
    PLDatabaseMigrationManagerTestsDelegateMock *delegate = [[[PLDatabaseMigrationManagerTestsDelegateMock alloc] initWithNewVersion: TEST_DATABASE_VERSION shouldFail: NO] autorelease];

    _versionManager = [[PLSqliteMigrationManager alloc] init];
    _dbManager = [[PLDatabaseMigrationManager alloc] initWithTransactionManager: _versionManager
                                                                 versionManager: _versionManager 
                                                                       delegate: delegate];
    STAssertNotNil(_dbManager, @"Could not create a new db manager");
}


- (void) tearDown {
	BOOL result;
    
	/* Clean out the test directory */
    result = [[NSFileManager defaultManager] removeItemAtPath: _testDir error: NULL];
	STAssertTrue(result, @"Deletion of test directory returned error");
    
	[_testDir release];
    [_dbManager release];
    [_versionManager release];
}


- (void) testMigrate {
    NSError *error;
    int version;
    PLSqliteDatabase *database = [PLSqliteDatabase databaseWithPath: @":memory:"];
    STAssertTrue([database openAndReturnError: &error], @"Could not get db connection: %@", error);

    /* Get the current version (should be 0) */
    STAssertTrue([_versionManager version: &version forDatabase: database error: &error], @"Could not retrieve version: %@", error);
    STAssertTrue(0 == version, @"Expected database version 0, got %d", version);

    /* Run the migration */
    STAssertTrue([_dbManager migrateDatabase: database error: &error], @"Migration failed: %@", error);
    
    /* Verify that our table was created and the version was bumped */
    STAssertTrue([_versionManager version: &version forDatabase: database error: &error], @"Could not retrieve version: %@", error);
    STAssertTrue(TEST_DATABASE_VERSION == version, @"Expected database version %d, got %d", TEST_DATABASE_VERSION, version);
    STAssertTrue([database tableExists: @"testtable"], @"Test table was not created");

    /* Clean up */
    [database close];
}


- (void) testMigrateRollback {
    PLDatabaseMigrationManagerTestsDelegateMock *delegate;
    PLDatabaseMigrationManager *dbManager;
    NSError *error;
    
    /* Set up our delegate */
    delegate = [[[PLDatabaseMigrationManagerTestsDelegateMock alloc] initWithNewVersion: TEST_DATABASE_VERSION shouldFail: YES] autorelease];    
    dbManager = [[[PLDatabaseMigrationManager alloc] initWithTransactionManager: _versionManager
                                                                 versionManager: _versionManager 
                                                                       delegate: delegate] autorelease];
    
    /* Create a test database */
    PLSqliteDatabase *database = [PLSqliteDatabase databaseWithPath: @":memory:"];
    STAssertTrue([database openAndReturnError: &error], @"Could not get db connection: %@", error);

    /* Run the migration (will fail, should roll back)  */
    STAssertFalse([dbManager migrateDatabase: database error: NULL], @"Migration was expected to fail");

    int version;
    STAssertTrue([_versionManager version: &version forDatabase: database error: &error], @"Could not retrieve database version: %@", error);
    STAssertEquals(0, version, @"The transaction was not rolled back, version is not 0");
    STAssertFalse([database tableExists: @"testtable"], @"The transaction was not rolled back, table exists");

    /* Clean up */
    [database close];
}

/**
 * Test handling of migrations that do not set the newVersion.
 */
- (void) testDoNothingMigration {
    PLDatabaseMigrationManagerTestsDelegateDoNothingMock *delegate;
    PLDatabaseMigrationManager *dbManager;
    NSError *error;
    
    /* Fetch a db connection */
    PLSqliteDatabase *database = [PLSqliteDatabase databaseWithPath: @":memory:"];
    STAssertTrue([database openAndReturnError: &error], @"Could not get db connection: %@", error);

    /* Start with a non-zero version */
    assert(TEST_DATABASE_VERSION != 0);
    STAssertTrue([_versionManager setVersion: TEST_DATABASE_VERSION forDatabase: database error: &error], @"Could not set version: %@", error);

    /* Set up our delegate (will fail, should roll back) */
    delegate = [[[PLDatabaseMigrationManagerTestsDelegateDoNothingMock alloc] init] autorelease];
    dbManager = [[[PLDatabaseMigrationManager alloc] initWithTransactionManager: _versionManager
                                                                 versionManager: _versionManager 
                                                                       delegate: delegate] autorelease];
    
    /* Run the migration */
    STAssertTrue([_dbManager migrateDatabase: database error: &error], @"Migration failed: %@", error);
    
    /* Verify that the version remains at TEST_DATABASE_VERSION */
    int version;
    STAssertTrue([_versionManager version: &version forDatabase: database error: &error], @"Could not retrieve database version: %@", error);
    STAssertEquals(TEST_DATABASE_VERSION, version, @"The database version was reset");

    /* Clean up */
    [database close];
}

@end
