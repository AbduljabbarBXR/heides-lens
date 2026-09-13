// Large fixture - services/api.ts
import { UserService } from '../services/user';
import { OrderService } from '../services/order';
import { PaymentService } from '../services/payment';

export class ApiController {
  constructor(
    private users: UserService,
    private orders: OrderService,
    private payments: PaymentService
  ) {}

  async handleRequest(req: Request): Promise<Response> {
    const { path } = req;
    if (path === '/users') return this.users.list();
    if (path === '/orders') return this.orders.list();
    return this.payments.process(req);
  }
}
