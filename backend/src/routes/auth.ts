import { type FastifyPluginAsync } from 'fastify';

import {
  type AuthService,
  type LoginInput,
  type OAuthInput,
  type RefreshInput,
  type ResendVerificationInput,
  type RegisterInput,
  type VerifyEmailInput,
} from '../services/auth/auth-service';

type AuthRouteOptions = {
  authService: AuthService;
};

const authRoute: FastifyPluginAsync<AuthRouteOptions> = async (app, options) => {
  app.post<{ Body: RegisterInput }>('/auth/register', async (request, reply) => {
    const result = await options.authService.register(request.body);
    reply.code(201).send(result);
  });

  app.post<{ Body: VerifyEmailInput }>(
    '/auth/verify-email',
    async (request) => options.authService.verifyEmail(request.body),
  );

  app.post<{ Body: ResendVerificationInput }>(
    '/auth/resend-verification',
    async (request) => options.authService.resendVerification(request.body),
  );

  app.post<{ Body: LoginInput }>('/auth/login', async (request) =>
    options.authService.login({
      ...request.body,
      userAgent: request.headers['user-agent'],
      ipAddress: request.ip,
    }));

  app.post<{ Body: RefreshInput }>('/auth/refresh', async (request) =>
    options.authService.refresh({
      ...request.body,
      userAgent: request.headers['user-agent'],
      ipAddress: request.ip,
    }));

  app.post<{ Body: OAuthInput }>('/auth/oauth', async (request) =>
    options.authService.oauth({
      ...request.body,
      userAgent: request.headers['user-agent'],
      ipAddress: request.ip,
    }));

  app.post<{ Body: { refreshToken: string } }>(
    '/auth/logout',
    async (request, reply) => {
      await options.authService.logout({
        refreshToken: request.body.refreshToken,
      });
      reply.code(204).send();
    },
  );
};

export default authRoute;
