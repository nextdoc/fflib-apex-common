/**
 * Copyright (c), FinancialForce.com, inc
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without modification,
 *   are permitted provided that the following conditions are met:
 *
 * - Redistributions of source code must retain the above copyright notice,
 *      this list of conditions and the following disclaimer.
 * - Redistributions in binary form must reproduce the above copyright notice,
 *      this list of conditions and the following disclaimer in the documentation
 *      and/or other materials provided with the distribution.
 * - Neither the name of the FinancialForce.com, inc nor the names of its contributors
 *      may be used to endorse or promote products derived from this software without
 *      specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
 *  ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
 *  OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL
 *  THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
 *  EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 *  OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY
 *  OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 *  ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */
/**
 * Utility class for checking FLS/CRUD. NOTE: all "check" methods will throw a SecurityException (or subclass) if the
 * user does not have the proper security granted.
 **/
@NamespaceAccessible
@SuppressWarnings(
  'PMD.ClassNamingConventions, PMD.MethodNamingConventions, PMD.FieldNamingConventions, PMD.PropertyNamingConventions, PMD.ApexDoc, PMD.CyclomaticComplexity, PMD.CognitiveComplexity, PMD.FieldDeclarationsShouldBeAtStart'
)
public inherited sharing class fflib_SecurityUtils {
  @TestVisible
  private enum OperationType {
    CREATE,
    READ,
    MODIFY,
    DEL
  } //UPDATE and DELETE are reserved words

  private static final Map<OperationType, String> CRUD_MESSAGES = new Map<OperationType, String>{
    OperationType.CREATE => System.Label.fflib_security_error_object_not_insertable,
    OperationType.READ => System.Label.fflib_security_error_object_not_readable,
    OperationType.MODIFY => System.Label.fflib_security_error_object_not_updateable,
    OperationType.DEL => System.Label.fflib_security_error_object_not_deletable
  };

  private static final Map<OperationType, String> FLS_MESSAGES = new Map<OperationType, String>{
    OperationType.CREATE => System.Label.fflib_security_error_field_not_insertable,
    OperationType.READ => System.Label.fflib_security_error_field_not_readable,
    OperationType.MODIFY => System.Label.fflib_security_error_field_not_updateable
  };

  /**
   * SecurityException is never be thrown directly by fflib_SecurityUtils, instead all
   * forms of CRUD and FLD violations throw subclasses of it. It is provided as a convenience
   * in the event you wish to handle CRUD and FLS violations the same way (e.g. die and display an error)
   **/
  @NamespaceAccessible
  public virtual inherited sharing class SecurityException extends Exception {
    @NamespaceAccessible
    protected OperationType m_operation;
    @NamespaceAccessible
    protected Schema.SObjectType m_objectType;
  }

  /**
   * CrudException represents a running user's lack of read/create/update/delete access at a profile (or permission set)
   * level. Sharing and field level security issues will never cause this.
   **/
  @NamespaceAccessible
  public inherited sharing class CrudException extends SecurityException {
    private CrudException(
      OperationType operation,
      Schema.SObjectType objectType
    ) {
      this.m_operation = operation;
      this.m_objectType = objectType;
      String objectName = objectType.getDescribe().getName();
      this.setMessage(
        String.format(
          CRUD_MESSAGES.get(operation),
          new List<String>{ objectName }
        )
      );
    }
  }
  /**
   * FlsException represents a running user's lack of field level security to a specific field at a profile (or permission set) level
   * Sharing and CRUD security issues will never cause this to be thrown.
   **/
  @NamespaceAccessible
  public inherited sharing class FlsException extends SecurityException {
    private Schema.SObjectField m_fieldToken;

    private FlsException(
      OperationType operation,
      Schema.SObjectType objectType,
      Schema.SObjectField fieldToken
    ) {
      this.m_operation = operation;
      this.m_objectType = objectType;
      this.m_fieldToken = fieldToken;
      String objectName = objectType.getDescribe().getName();
      String fieldName = fieldToken.getDescribe().getName();
      this.setMessage(
        String.format(
          FLS_MESSAGES.get(operation),
          new List<String>{ objectName, fieldName }
        )
      );
    }
  }

  /**
   * If set to true all check methods will always return void, and never throw exceptions.
   * This should really only be set to true if an app-wide setting to disable in-apex
   * FLS and CRUD checks exists and is enabled.
   * Per security best practices setting BYPASS should be an a opt-in, and not the default behavior.
   **/
  @NamespaceAccessible
  public static Boolean BYPASS_INTERNAL_FLS_AND_CRUD = false;

  private static SObjectType cachedDescribeType;
  private static fflib_SObjectDescribe cachedDescribe;

  private static fflib_SObjectDescribe describeFor(SObjectType objType) {
    if (objType != cachedDescribeType) {
      cachedDescribe = fflib_SObjectDescribe.getDescribe(objType);
      cachedDescribeType = objType;
    }
    return cachedDescribe;
  }

  private static Map<SObjectType, Map<String, SObjectField>> fieldTokenCache = new Map<SObjectType, Map<String, SObjectField>>();

  private static SObjectField fieldTokenFor(
    SObjectType objType,
    String fieldName
  ) {
    return fieldTokenFor(objType, fieldTokensFor(objType), fieldName);
  }

  private static Map<String, SObjectField> fieldTokensFor(SObjectType objType) {
    Map<String, SObjectField> tokens = fieldTokenCache.get(objType);
    if (tokens == null) {
      tokens = new Map<String, SObjectField>();
      fieldTokenCache.put(objType, tokens);
    }
    return tokens;
  }

  private static SObjectField fieldTokenFor(
    SObjectType objType,
    Map<String, SObjectField> tokens,
    String fieldName
  ) {
    SObjectField token = tokens.get(fieldName);
    if (token == null) {
      fflib_SObjectDescribe describe = describeFor(objType);
      if (describe == null) {
        throw new NullPointerException();
      }
      token = describe.getField(fieldName);
      tokens.put(fieldName, token);
    }
    return token;
  }

  private static Id fieldDescribeCacheUserId;
  private static Map<SObjectType, Map<String, DescribeFieldResult>> fieldDescribeCache = new Map<SObjectType, Map<String, DescribeFieldResult>>();

  private static Map<SObjectType, Set<List<String>>> verifiedReadLists = new Map<SObjectType, Set<List<String>>>();
  private static Map<SObjectType, Set<List<String>>> verifiedInsertLists = new Map<SObjectType, Set<List<String>>>();
  private static Map<SObjectType, Set<List<String>>> verifiedUpdateLists = new Map<SObjectType, Set<List<String>>>();

  private static void resetCachesIfUserChanged() {
    Id userId = UserInfo.getUserId();
    if (userId != fieldDescribeCacheUserId) {
      fieldDescribeCache.clear();
      verifiedReadLists.clear();
      verifiedInsertLists.clear();
      verifiedUpdateLists.clear();
      fieldDescribeCacheUserId = userId;
    }
  }

  private static Set<List<String>> verifiedListsFor(
    Map<SObjectType, Set<List<String>>> byType,
    SObjectType objType
  ) {
    resetCachesIfUserChanged();
    Set<List<String>> verified = byType.get(objType);
    if (verified == null) {
      verified = new Set<List<String>>();
      byType.put(objType, verified);
    }
    return verified;
  }

  private static Map<String, DescribeFieldResult> fieldDescribesFor(
    SObjectType objType
  ) {
    Map<String, DescribeFieldResult> describes = fieldDescribeCache.get(
      objType
    );
    if (describes == null) {
      describes = new Map<String, DescribeFieldResult>();
      fieldDescribeCache.put(objType, describes);
    }
    return describes;
  }

  private static DescribeFieldResult fieldDescribeFor(
    SObjectType objType,
    Map<String, DescribeFieldResult> describes,
    String fieldName
  ) {
    DescribeFieldResult fieldDescribe = describes.get(fieldName);
    if (fieldDescribe == null) {
      fieldDescribe = fieldTokenFor(objType, fieldName).getDescribe();
      describes.put(fieldName, fieldDescribe);
    }
    return fieldDescribe;
  }

  /**
   * Check{Insert,Read,Update} methods check both FLS and CRUD
   **/

  /**
   * Checks both insert FLS and CRUD for the specified object type and fields.
   * @exception FlsException if the running user does not have insert rights to any fields in {@code fieldNames}.
   * @exception CrudException if the running user does not have insert rights to {@code objType}
   **/
  @NamespaceAccessible
  public static void checkInsert(SObjectType objType, List<String> fieldNames) {
    checkObjectIsInsertable(objType);
    Set<List<String>> verified = verifiedListsFor(verifiedInsertLists, objType);
    if (verified.contains(fieldNames)) {
      return;
    }
    Map<String, DescribeFieldResult> describes = fieldDescribesFor(objType);
    for (String fieldName : fieldNames) {
      checkFieldIsInsertable(
        objType,
        fieldDescribeFor(objType, describes, fieldName)
      );
    }
    if (!BYPASS_INTERNAL_FLS_AND_CRUD) {
      verified.add(fieldNames.clone());
    }
  }

  /**
   * Identical to {@link #checkInsert(SObjectType,List<String>)}, except with SObjectField instead of String field references.
   * @exception FlsException if the running user does not have insert rights to any fields in {@code fieldTokens}.
   * @exception CrudException if the running user does not have insert rights to {@code objType}
   **/
  @NamespaceAccessible
  public static void checkInsert(
    SObjectType objType,
    List<SObjectField> fieldTokens
  ) {
    checkObjectIsInsertable(objType);
    for (SObjectField fieldToken : fieldTokens) {
      checkFieldIsInsertable(objType, fieldToken);
    }
  }

  /**
   * Checks both read FLS and CRUD for the specified object type and fields.
   * @exception FlsException if the running user does not have read rights to any fields in {@code fieldNames}.
   * @exception CrudException if the running user does not have read rights to {@code objType}
   **/
  @NamespaceAccessible
  public static void checkRead(SObjectType objType, List<String> fieldNames) {
    checkObjectIsReadable(objType);
    Set<List<String>> verified = verifiedListsFor(verifiedReadLists, objType);
    if (verified.contains(fieldNames)) {
      return;
    }
    Map<String, DescribeFieldResult> describes = fieldDescribesFor(objType);
    for (String fieldName : fieldNames) {
      checkFieldIsReadable(
        objType,
        fieldDescribeFor(objType, describes, fieldName)
      );
    }
    if (!BYPASS_INTERNAL_FLS_AND_CRUD) {
      verified.add(fieldNames.clone());
    }
  }

  /**
   * Identical to {@link #checkRead(SObjectType,List<String>)}, except with SObjectField instead of String field references.
   * @exception FlsException if the running user does not have read rights to any fields in {@code fieldTokens}.
   * @exception CrudException if the running user does not have read rights to {@code objType}
   **/
  @NamespaceAccessible
  public static void checkRead(
    SObjectType objType,
    List<SObjectField> fieldTokens
  ) {
    checkObjectIsReadable(objType);
    for (SObjectField fieldToken : fieldTokens) {
      checkFieldIsReadable(objType, fieldToken);
    }
  }

  /**
   * Checks both update FLS and CRUD for the specified object type and fields.
   * @exception FlsException if the running user does not have update rights to any fields in {@code fieldNames}.
   * @exception CrudException if the running user does not have update rights to {@code objType}
   **/
  @NamespaceAccessible
  public static void checkUpdate(SObjectType objType, List<String> fieldNames) {
    checkObjectIsUpdateable(objType);
    Set<List<String>> verified = verifiedListsFor(verifiedUpdateLists, objType);
    if (verified.contains(fieldNames)) {
      return;
    }
    Map<String, DescribeFieldResult> describes = fieldDescribesFor(objType);
    for (String fieldName : fieldNames) {
      checkFieldIsUpdateable(
        objType,
        fieldDescribeFor(objType, describes, fieldName)
      );
    }
    if (!BYPASS_INTERNAL_FLS_AND_CRUD) {
      verified.add(fieldNames.clone());
    }
  }

  /**
   * Identical to {@link #checkUpdate(SObjectType,List<String>)}, except with SObjectField instead of String field references.
   * @exception FlsException if the running user does not have update rights to any fields in {@code fieldTokens}.
   * @exception CrudException if the running user does not have update rights to {@code objType}
   **/
  @NamespaceAccessible
  public static void checkUpdate(
    SObjectType objType,
    List<SObjectField> fieldTokens
  ) {
    checkObjectIsUpdateable(objType);
    for (SObjectField fieldToken : fieldTokens) {
      checkFieldIsUpdateable(objType, fieldToken);
    }
  }

  /**
   * CheckFieldIs* method check only FLS
   **/

  /**
   * Checks insert field level security only (no CRUD) for the specified fields on {@code objType}
   * @exception FlsException if the running user does not have insert rights to the {@code fieldName} field.
   **/
  @NamespaceAccessible
  public static void checkFieldIsInsertable(
    SObjectType objType,
    String fieldName
  ) {
    SObjectField fieldToken = fieldTokenFor(objType, fieldName);
    checkFieldIsInsertable(objType, fieldToken);
  }

  /**
   * Identical to {@link #checkFieldIsInsertable(SObjectType,String)}, except with SObjectField instead of String field reference.
   * @exception FlsException if the running user does not have insert rights to the {@code fieldName} field.
   **/
  @NamespaceAccessible
  public static void checkFieldIsInsertable(
    SObjectType objType,
    SObjectField fieldToken
  ) {
    DescribeFieldResult fieldDescribe = fieldToken.getDescribe();
    checkFieldIsInsertable(objType, fieldDescribe);
  }

  /**
   * Identical to {@link #checkFieldIsInsertable(SObjectType,String)}, except with DescribeFieldResult instead of String field reference.
   * @exception FlsException if the running user does not have insert rights to the {@code fieldName} field.
   **/
  @NamespaceAccessible
  public static void checkFieldIsInsertable(
    SObjectType objType,
    DescribeFieldResult fieldDescribe
  ) {
    if (BYPASS_INTERNAL_FLS_AND_CRUD) {
      return;
    }
    requireFieldAccess(
      OperationType.CREATE,
      objType,
      fieldDescribe.isCreateable() ? null : fieldDescribe
    );
  }

  /**
   * Checks read field level security only (no CRUD) for the specified fields on {@code objType}
   * @exception FlsException if the running user does not have read rights to the {@code fieldName} field.
   **/
  @NamespaceAccessible
  public static void checkFieldIsReadable(
    SObjectType objType,
    String fieldName
  ) {
    SObjectField fieldToken = fieldTokenFor(objType, fieldName);
    checkFieldIsReadable(objType, fieldToken);
  }

  /**
   * Identical to {@link #checkFieldIsReadable(SObjectType,String)}, except with SObjectField instead of String field reference.
   * @exception FlsException if the running user does not have read rights to the {@code fieldName} field.
   **/
  @NamespaceAccessible
  public static void checkFieldIsReadable(
    SObjectType objType,
    SObjectField fieldToken
  ) {
    DescribeFieldResult fieldDescribe = fieldToken.getDescribe();
    checkFieldIsReadable(objType, fieldDescribe);
  }

  /**
   * Identical to {@link #checkFieldIsReadable(SObjectType,String)}, except with DescribeFieldResult instead of String field reference.
   * @exception FlsException if the running user does not have read rights to the {@code fieldName} field.
   **/
  @NamespaceAccessible
  public static void checkFieldIsReadable(
    SObjectType objType,
    DescribeFieldResult fieldDescribe
  ) {
    if (BYPASS_INTERNAL_FLS_AND_CRUD) {
      return;
    }
    requireFieldAccess(
      OperationType.READ,
      objType,
      fieldDescribe.isAccessible() ? null : fieldDescribe
    );
  }

  /**
   * Checks update field level security only (no CRUD) for the specified fields on {@code objType}
   * @exception FlsException if the running user does not have update rights to the {@code fieldName} field.
   **/
  @NamespaceAccessible
  public static void checkFieldIsUpdateable(
    SObjectType objType,
    String fieldName
  ) {
    SObjectField fieldToken = fieldTokenFor(objType, fieldName);
    checkFieldIsUpdateable(objType, fieldToken);
  }

  /**
   * Identical to {@link #checkFieldIsUpdateable(SObjectType,String)}, except with SObjectField instead of String field reference.
   * @exception FlsException if the running user does not have update rights to the {@code fieldName} field.
   **/
  @NamespaceAccessible
  public static void checkFieldIsUpdateable(
    SObjectType objType,
    SObjectField fieldToken
  ) {
    DescribeFieldResult fieldDescribe = fieldToken.getDescribe();
    checkFieldIsUpdateable(objType, fieldDescribe);
  }

  /**
   * Identical to {@link #checkFieldIsUpdateable(SObjectType,String)}, except with DescribeFieldResult instead of String field reference.
   * @exception FlsException if the running user does not have update rights to the {@code fieldName} field.
   **/
  @NamespaceAccessible
  public static void checkFieldIsUpdateable(
    SObjectType objType,
    DescribeFieldResult fieldDescribe
  ) {
    if (BYPASS_INTERNAL_FLS_AND_CRUD) {
      return;
    }
    requireFieldAccess(
      OperationType.MODIFY,
      objType,
      fieldDescribe.isUpdateable() ? null : fieldDescribe
    );
  }

  private static void requireFieldAccess(
    OperationType operation,
    SObjectType objType,
    DescribeFieldResult deniedField
  ) {
    if (deniedField != null) {
      throw new FlsException(operation, objType, deniedField.getSObjectField());
    }
  }

  private static void requireObjectAccess(
    Boolean allowed,
    OperationType operation,
    SObjectType objType
  ) {
    if (!allowed) {
      throw new CrudException(operation, objType);
    }
  }

  /**
   * CheckObjectIs* methods check only CRUD
   **/

  /**
   * Checks insert CRUD for the specified object type.
   * @exception CrudException if the running user does not have insert rights to the {@code objType} SObject.
   **/
  @NamespaceAccessible
  public static void checkObjectIsInsertable(SObjectType objType) {
    if (BYPASS_INTERNAL_FLS_AND_CRUD) {
      return;
    }
    requireObjectAccess(
      objType.getDescribe().isCreateable(),
      OperationType.CREATE,
      objType
    );
  }

  /**
   * Checks read CRUD for the specified object type.
   * @exception CrudException if the running user does not have read rights to the {@code objType} SObject.
   **/
  @NamespaceAccessible
  public static void checkObjectIsReadable(SObjectType objType) {
    if (BYPASS_INTERNAL_FLS_AND_CRUD) {
      return;
    }
    requireObjectAccess(
      objType.getDescribe().isAccessible(),
      OperationType.READ,
      objType
    );
  }

  /**
   * Checks update CRUD for the specified object type.
   * @exception CrudException if the running user does not have update rights to the {@code objType} SObject.
   **/
  @NamespaceAccessible
  public static void checkObjectIsUpdateable(SObjectType objType) {
    if (BYPASS_INTERNAL_FLS_AND_CRUD) {
      return;
    }
    requireObjectAccess(
      objType.getDescribe().isUpdateable(),
      OperationType.MODIFY,
      objType
    );
  }

  /**
   * Checks delete CRUD for the specified object type.
   * @exception CrudException if the running user does not have delete rights to the {@code objType} SObject.
   **/
  @NamespaceAccessible
  public static void checkObjectIsDeletable(SObjectType objType) {
    if (BYPASS_INTERNAL_FLS_AND_CRUD) {
      return;
    }
    requireObjectAccess(
      objType.getDescribe().isDeletable(),
      OperationType.DEL,
      objType
    );
  }
}
