export interface ApiUser {
  success: boolean;
  user: {
    email: string;
    fullName: string;
    id: number;
    name: string;
    surname: string;
  };
}

export class User {
  id!: number;
  email!: string;
  firstName!: string;
  lastName!: string;
  fullName!: string;

  static fromApi(apiUser: ApiUser['user']): User {
    const user = new User();
    user.id = apiUser.id;
    user.email = apiUser.email;
    user.firstName = apiUser.name;
    user.lastName = apiUser.surname;
    user.fullName = apiUser.fullName;
    return user;
  }
}