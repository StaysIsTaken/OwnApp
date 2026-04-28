import 'package:productivity/dataclasses/User.dart';
import 'package:productivity/dataservice/api_client.dart';

class UserService {
  UserService._();

  static Future<List<User>> getAllUsers() async {
    final response = await ApiClient.dio.get('/users/');
    // API returns a direct list based on the endpoint definition
    final list = response.data as List<dynamic>;
    return list.map((e) => User.fromJson(e)).toList();
  }
}
