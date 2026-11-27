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
import { type ActionQuotaGuard } from '../security/distributed-action-quota';

type AuthRouteOptions = {
  authService: AuthService;
  actionQuotaGuard: ActionQuotaGuard;
};

const authRoute: FastifyPluginAsync<AuthRouteOptions> = async (
  app,
  options,
) => {
  app.post<{ Body: RegisterInput }>(
    '/auth/register',
    async (request, reply) => {
      await options.actionQuotaGuard.enforce({
        action: 'auth.register',
        dimensions: { ip: request.ip, account: request.body.email },
      });
      const result = await options.authService.register(request.body);
      reply.code(201).send(result);
    },
  );

  app.post<{ Body: VerifyEmailInput }>(
    '/auth/verify-email',
    async (request) => {
      await options.actionQuotaGuard.enforce({
        action: 'auth.verify',
        dimensions: {
          ip: request.ip,
          session:
            'tokenHash' in request.body
              ? request.body.tokenHash
              : request.body.token,
        },
      });
      return options.authService.verifyEmail(request.body);
    },
  );

  app.post<{ Body: ResendVerificationInput }>(
    '/auth/resend-verification',
    async (request) => {
      await options.actionQuotaGuard.enforce({
        action: 'auth.resend',
        dimensions: { ip: request.ip, account: request.body.email },
      });
      return options.authService.resendVerification(request.body);
    },
  );

  app.post<{ Body: LoginInput }>('/auth/login', async (request) => {
    await options.actionQuotaGuard.enforce({
      action: 'auth.login',
      dimensions: { ip: request.ip, account: request.body.email },
    });
    return options.authService.login({
      ...request.body,
      userAgent: request.headers['user-agent'],
      ipAddress: request.ip,
    });
  });

  app.post<{ Body: RefreshInput }>('/auth/refresh', async (request) => {
    await options.actionQuotaGuard.enforce({
      action: 'auth.refresh',
      dimensions: { ip: request.ip, session: request.body.refreshToken },
    });
    return options.authService.refresh({
      ...request.body,
      userAgent: request.headers['user-agent'],
      ipAddress: request.ip,
    });
  });

  app.post<{ Body: OAuthInput }>('/auth/oauth', async (request) => {
    await options.actionQuotaGuard.enforce({
      action: 'auth.oauth',
      dimensions: { ip: request.ip, session: request.body.credential },
    });
    return options.authService.oauth({
      ...request.body,
      userAgent: request.headers['user-agent'],
      ipAddress: request.ip,
    });
  });

  app.post<{ Body: { refreshToken: string } }>(
    '/auth/logout',
    async (request, reply) => {
      await options.actionQuotaGuard.enforce({
        action: 'auth.logout',
        dimensions: { ip: request.ip, session: request.body.refreshToken },
      });
      await options.authService.logout({
        refreshToken: request.body.refreshToken,
      });
      reply.code(204).send();
    },
  );
};

export default authRoute;
