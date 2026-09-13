// Large fixture - services/user.ts
import { Database } from '../models/database';
import { Cache } from '../utils/cache';

export class UserService {
  constructor(private db: Database, private cache: Cache) {}

  async list() {
    const cached = this.cache.get('users');
    if (cached) return cached;
    const users = await this.db.query('SELECT * FROM users');
    this.cache.set('users', users);
    return users;
  }
}
