import { computed, Injectable, signal } from '@angular/core';
import { map, Observable, tap } from 'rxjs';
import { ApiUser, User } from '../../models/User/user';
import { HttpClient } from '@angular/common/http';
import { environment } from '../../../environments/environment';

@Injectable({
  providedIn: 'root',
})

export class UserService {
  private readonly base = environment.apiUrl;
  private readonly STORAGE_KEY = 'currentUser';

  private readonly _currentUser = signal<User | null>(null);
  readonly currentUser = this._currentUser.asReadonly();
  readonly isLoggedIn = computed(() => this._currentUser() !== null);

  constructor(private http: HttpClient) {}

  list(): Observable<User[]> {
    return this.http.get<User[]>(this.base);
  }

  get(id: number): Observable<User> {
    return this.http.get<User>(`${this.base}/${id}`);
  }


  create(data: {
    email: string;
    password: string;
    firstName: string;
    lastName: string;
  }): Observable<User> {
    return this.http.post<User>(this.base, data);
  }

  update(id: number, data: Partial<{
    email: string;
    password: string;
    firstName: string;
    lastName: string;
  }>): Observable<User> {
    return this.http.patch<User>(`${this.base}/${id}`, data);
  }

  login(data: { email: string; password: string }): Observable<User> {
    return this.http.post<ApiUser>(`${this.base}/login`, data).pipe(
      map(apiUser => User.fromApi(apiUser.user)),
      tap(user => this._currentUser.set(user))
    );
  }
  logout(): void {
    this._currentUser.set(null);
  }

}
