import { UserService } from './user';

export class OrderService {
  constructor(private userService: UserService) {}

  async getUserOrders(userId: string) {
    const user = await this.userService.getUser(userId);
    if (!user) return [];
    return user.orders;
  }
}
