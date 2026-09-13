// Medium fixture - sample TypeScript project
export class UserService {
  private users: Map<string, User> = new Map();

  async getUser(id: string): Promise<User | undefined> {
    return this.users.get(id);
  }

  async createUser(data: CreateUserRequest): Promise<User> {
    const user = new User(data.name, data.email);
    this.users.set(user.id, user);
    return user;
  }
}

export class AuthService {
  async validateToken(token: string): Promise<boolean> {
    // TODO: implement token validation
    return true;
  }
}
