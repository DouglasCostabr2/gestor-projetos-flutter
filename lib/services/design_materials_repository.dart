import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:my_business/modules/common/organization_context.dart';

/// Repository for managing design materials (folders, files, tags)
class DesignMaterialsRepository {
  final _client = Supabase.instance.client;

  // ============================================================================
  // TAGS
  // ============================================================================

  /// Get all tags for the current organization
  Future<List<Map<String, dynamic>>> getTags() async {
    final organizationId = OrganizationContext.currentOrganizationId;
    if (organizationId == null) {
      throw Exception('No organization selected');
    }

    final response = await _client
        .from('design_tags')
        .select()
        .eq('organization_id', organizationId)
        .order('name');

    return List<Map<String, dynamic>>.from(response);
  }

  /// Create a new tag
  Future<Map<String, dynamic>> createTag({
    required String name,
    String? color,
  }) async {
    final organizationId = OrganizationContext.currentOrganizationId;
    if (organizationId == null) {
      throw Exception('No organization selected');
    }

    final userId = _client.auth.currentUser?.id;

    final response = await _client
        .from('design_tags')
        .insert({
          'organization_id': organizationId,
          'name': name,
          'color': color,
          'created_by': userId,
        })
        .select()
        .single();

    return response;
  }

  /// Update a tag
  Future<void> updateTag({
    required String tagId,
    String? name,
    String? color,
  }) async {
    final data = <String, dynamic>{};
    if (name != null) data['name'] = name;
    if (color != null) data['color'] = color;

    if (data.isEmpty) return;

    await _client.from('design_tags').update(data).eq('id', tagId);
  }

  /// Delete a tag
  Future<void> deleteTag(String tagId) async {
    await _client.from('design_tags').delete().eq('id', tagId);
  }

  // ============================================================================
  // CLIENTS & COMPANIES (for cross-company file selection)
  // ============================================================================

  /// Get all clients with their companies for the current organization
  Future<List<Map<String, dynamic>>> getClientsWithCompanies() async {
    final organizationId = OrganizationContext.currentOrganizationId;
    if (organizationId == null) {
      throw Exception('No organization selected');
    }

    final response = await _client
        .from('clients')
        .select('''
          id,
          name,
          avatar_url,
          companies:companies(
            id,
            name
          )
        ''')
        .eq('organization_id', organizationId)
        .order('name');

    return List<Map<String, dynamic>>.from(response);
  }

  // ============================================================================
  // FOLDERS
  // ============================================================================

  /// Get all folders for a company
  Future<List<Map<String, dynamic>>> getFolders(String companyId) async {
    final organizationId = OrganizationContext.currentOrganizationId;
    if (organizationId == null) {
      throw Exception('No organization selected');
    }

    final response = await _client
        .from('design_folders')
        .select('''
          *,
          folder_tags:design_folder_tags(
            tag:design_tags(*)
          )
        ''')
        .eq('organization_id', organizationId)
        .eq('company_id', companyId)
        .order('name');

    return List<Map<String, dynamic>>.from(response);
  }

  /// Create a new folder
  Future<Map<String, dynamic>> createFolder({
    required String companyId,
    required String name,
    String? description,
    String? parentFolderId,
    String? driveFolderId,
  }) async {
    final organizationId = OrganizationContext.currentOrganizationId;
    if (organizationId == null) {
      throw Exception('No organization selected');
    }

    final userId = _client.auth.currentUser?.id;

    final response = await _client
        .from('design_folders')
        .insert({
          'organization_id': organizationId,
          'company_id': companyId,
          'name': name,
          'description': description,
          'parent_folder_id': parentFolderId,
          'drive_folder_id': driveFolderId,
          'created_by': userId,
          'updated_by': userId,
        })
        .select()
        .single();

    return response;
  }

  /// Update a folder
  Future<void> updateFolder({
    required String folderId,
    String? name,
    String? description,
    String? driveFolderId,
  }) async {
    final userId = _client.auth.currentUser?.id;
    final data = <String, dynamic>{
      'updated_by': userId,
      'updated_at': DateTime.now().toIso8601String(),
    };

    if (name != null) data['name'] = name;
    if (description != null) data['description'] = description;
    if (driveFolderId != null) data['drive_folder_id'] = driveFolderId;

    await _client.from('design_folders').update(data).eq('id', folderId);
  }

  /// Delete a folder (cascade deletes files and subfolders)
  Future<void> deleteFolder(String folderId) async {
    await _client.from('design_folders').delete().eq('id', folderId);
  }

  /// Add tag to folder
  Future<void> addTagToFolder(String folderId, String tagId) async {
    await _client.from('design_folder_tags').insert({
      'folder_id': folderId,
      'tag_id': tagId,
    });
  }

  /// Remove tag from folder
  Future<void> removeTagFromFolder(String folderId, String tagId) async {
    await _client
        .from('design_folder_tags')
        .delete()
        .eq('folder_id', folderId)
        .eq('tag_id', tagId);
  }

  // ============================================================================
  // FILES
  // ============================================================================

  /// Get all files for a company (optionally filtered by folder)
  Future<List<Map<String, dynamic>>> getFiles(String companyId, {String? folderId}) async {
    final organizationId = OrganizationContext.currentOrganizationId;
    if (organizationId == null) {
      throw Exception('No organization selected');
    }

    var query = _client
        .from('design_files')
        .select('''
          *,
          file_tags:design_file_tags(
            tag:design_tags(*)
          )
        ''')
        .eq('organization_id', organizationId)
        .eq('company_id', companyId);

    if (folderId != null) {
      query = query.eq('folder_id', folderId);
    }

    final response = await query.order('filename');

    return List<Map<String, dynamic>>.from(response);
  }

  /// Create a new file record
  Future<Map<String, dynamic>> createFile({
    required String companyId,
    required String filename,
    required String driveFileId,
    String? folderId,
    int? fileSizeBytes,
    String? mimeType,
    String? description,
    String? driveFileUrl,
    String? driveThumbnailUrl,
  }) async {
    final organizationId = OrganizationContext.currentOrganizationId;
    if (organizationId == null) {
      throw Exception('No organization selected');
    }

    final userId = _client.auth.currentUser?.id;

    final response = await _client
        .from('design_files')
        .insert({
          'organization_id': organizationId,
          'company_id': companyId,
          'folder_id': folderId,
          'filename': filename,
          'file_size_bytes': fileSizeBytes,
          'mime_type': mimeType,
          'description': description,
          'drive_file_id': driveFileId,
          'drive_file_url': driveFileUrl,
          'drive_thumbnail_url': driveThumbnailUrl,
          'created_by': userId,
          'updated_by': userId,
        })
        .select()
        .single();

    return response;
  }

  /// Update a file record
  Future<void> updateFile({
    required String fileId,
    String? filename,
    String? description,
    String? driveFileUrl,
    String? driveThumbnailUrl,
  }) async {
    final userId = _client.auth.currentUser?.id;
    final data = <String, dynamic>{
      'updated_by': userId,
      'updated_at': DateTime.now().toIso8601String(),
    };

    if (filename != null) data['filename'] = filename;
    if (description != null) data['description'] = description;
    if (driveFileUrl != null) data['drive_file_url'] = driveFileUrl;
    if (driveThumbnailUrl != null) data['drive_thumbnail_url'] = driveThumbnailUrl;

    await _client.from('design_files').update(data).eq('id', fileId);
  }

  /// Delete a file record
  Future<void> deleteFile(String fileId) async {
    await _client.from('design_files').delete().eq('id', fileId);
  }

  /// Add tag to file
  Future<void> addTagToFile(String fileId, String tagId) async {
    await _client.from('design_file_tags').insert({
      'file_id': fileId,
      'tag_id': tagId,
    });
  }

  /// Remove tag from file
  Future<void> removeTagFromFile(String fileId, String tagId) async {
    await _client
        .from('design_file_tags')
        .delete()
        .eq('file_id', fileId)
        .eq('tag_id', tagId);
  }

  /// Search files and folders by tag
  Future<Map<String, dynamic>> searchByTags(String companyId, List<String> tagIds) async {
    final organizationId = OrganizationContext.currentOrganizationId;
    if (organizationId == null) {
      throw Exception('No organization selected');
    }

    // Get folders with these tags
    final foldersResponse = await _client
        .from('design_folders')
        .select('''
          *,
          folder_tags:design_folder_tags!inner(
            tag_id
          )
        ''')
        .eq('organization_id', organizationId)
        .eq('company_id', companyId)
        .inFilter('folder_tags.tag_id', tagIds);

    // Get files with these tags
    final filesResponse = await _client
        .from('design_files')
        .select('''
          *,
          file_tags:design_file_tags!inner(
            tag_id
          )
        ''')
        .eq('organization_id', organizationId)
        .eq('company_id', companyId)
        .inFilter('file_tags.tag_id', tagIds);

    return {
      'folders': List<Map<String, dynamic>>.from(foldersResponse),
      'files': List<Map<String, dynamic>>.from(filesResponse),
    };
  }
}

