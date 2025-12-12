import { Component, inject, signal } from '@angular/core';
import { MatFormFieldModule } from '@angular/material/form-field';
import { MatInputModule } from '@angular/material/input';
import {FormControl, FormsModule, ReactiveFormsModule, Validators} from '@angular/forms';
import { merge } from 'rxjs';
import {takeUntilDestroyed} from '@angular/core/rxjs-interop';
import {MatButtonModule} from '@angular/material/button';
import { Router } from '@angular/router';

import { UserService } from '../../services/UserService/user-service';

@Component({
  selector: 'app-login',
  imports: [
    MatFormFieldModule,
    MatInputModule,
    FormsModule,
    ReactiveFormsModule,
    MatButtonModule
  ],
  templateUrl: './login.html',
  styleUrl: './login.css',
})
export class Login {
  readonly email = new FormControl('', [Validators.required, Validators.email]);
  emailErrorMessage = signal('');
  readonly password = new FormControl('', [Validators.required]);
  passwordErrorMessage = signal('');
  readonly errorLogin = signal('');
  private router = inject(Router);

  constructor(
    private userService: UserService
  ) {
    merge(this.email.statusChanges, this.email.valueChanges)
      .pipe(takeUntilDestroyed())
      .subscribe(() => this.updateErrorMessage())
  }

  updateErrorMessage() {
    if (this.email.hasError('required')) {
      this.emailErrorMessage.set('You must enter a value');
    } else if (this.email.hasError('email')) {
      this.emailErrorMessage.set('Not a valid email');
    } else {
      this.emailErrorMessage.set('');
    }
  }

  login() {
    if (this.email.invalid) {
      this.emailErrorMessage.set('Please enter a valid email before logging in.');
      return;
    } else if (this.password.invalid) {
      this.passwordErrorMessage.set('Please enter your password before logging in.');
      return;
    }
    this.userService.login({ email: this.email.value || '', password: this.password.value || '' })
      .subscribe({
        next: user => {
          console.log('Logged in user:', user);
          this.router.navigate(['/home']);
        },
        error: err => {
          this.errorLogin.set('Login failed. Please check your credentials and try again.');
        }
      });
  }

}
