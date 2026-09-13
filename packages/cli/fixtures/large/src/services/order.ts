// Large fixture - services/order.ts
import { UserService } from './user';

export class OrderService {
  constructor(private users: UserService) {}

  async list() {
    return [];
  }
}
