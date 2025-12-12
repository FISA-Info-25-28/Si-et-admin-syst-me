import { Routes } from '@angular/router';
import {
    Home,
    Login
} from './views';
import { authGuard } from './guard/login.guard';

export const routes: Routes = [
  { path: 'login', component: Login },

  { path: '', component: Home, canActivate: [authGuard] },

  { path: '**', redirectTo: '' }
];
