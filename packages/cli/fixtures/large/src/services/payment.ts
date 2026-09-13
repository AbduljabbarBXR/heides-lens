// Large fixture - services/payment.ts
export class PaymentService {
  async process(req: Request): Promise<Response> {
    return new Response('OK');
  }
}
