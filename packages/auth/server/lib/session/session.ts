import { sha256 } from '@oslojs/crypto/sha2';
import { encodeBase32LowerCaseNoPadding, encodeHexLowerCase } from '@oslojs/encoding';
import { type Session, type User, UserSecurityAuditLogType } from '@prisma/client';

import type { RequestMetadata } from '@documenso/lib/universal/extract-request-metadata';
import { prisma } from '@documenso/prisma';

export type SessionValidationResult =
  | {
      session: Session;
      user: User;
      // user: Pick<
      //   User,
      //   'id' | 'name' | 'email' | 'emailVerified' | 'avatarImageId' | 'twoFactorEnabled' | 'roles' // Todo
      // >;
      isAuthenticated: true;
    }
  | { session: null; user: null; isAuthenticated: false };

export const generateSessionToken = (): string => {
  const bytes = new Uint8Array(20);

  crypto.getRandomValues(bytes);

  const token = encodeBase32LowerCaseNoPadding(bytes);

  return token;
};

export const createSession = async (
  token: string,
  userId: number,
  metadata: RequestMetadata,
): Promise<Session> => {
  const hashedSessionId = encodeHexLowerCase(sha256(new TextEncoder().encode(token)));

  const session: Session = {
    id: hashedSessionId,
    sessionToken: hashedSessionId, // todo
    userId,
    updatedAt: new Date(),
    createdAt: new Date(),
    expiresAt: new Date(Date.now() + 1000 * 60 * 60 * 24 * 30),
    ipAddress: metadata.ipAddress ?? null,
    userAgent: metadata.userAgent ?? null,
  };

  await prisma.session.create({
    data: session,
  });

  await prisma.userSecurityAuditLog.create({
    data: {
      userId,
      ipAddress: metadata.ipAddress,
      userAgent: metadata.userAgent,
      type: UserSecurityAuditLogType.SIGN_IN,
    },
  });

  return session;
};

export const validateSessionToken = async (token: string): Promise<SessionValidationResult> => {
  const sessionId = encodeHexLowerCase(sha256(new TextEncoder().encode(token)));

  const result = await prisma.session.findUnique({
    where: {
      id: sessionId,
    },
    include: {
      user: true,
    },
  });

  // user: {
  //   select: {
  //     id: true,
  //     name: true,
  //     email: true,
  //     emailVerified: true,
  //     avatarImageId: true,
  //     twoFactorEnabled: true,
  //   },
  // },

  // todo; how can result.user be null?
  if (result === null || !result.user) {
    return { session: null, user: null, isAuthenticated: false };
  }

  const { user, ...session } = result;

  if (Date.now() >= session.expiresAt.getTime()) {
    await prisma.session.delete({ where: { id: sessionId } });
    return { session: null, user: null, isAuthenticated: false };
  }

  if (Date.now() >= session.expiresAt.getTime() - 1000 * 60 * 60 * 24 * 15) {
    session.expiresAt = new Date(Date.now() + 1000 * 60 * 60 * 24 * 30);

    await prisma.session.update({
      where: {
        id: session.id,
      },
      data: {
        expiresAt: session.expiresAt,
      },
    });
  }

  return { session, user, isAuthenticated: true };
};

export const invalidateSession = async (
  sessionId: string,
  metadata: RequestMetadata,
): Promise<void> => {
  const session = await prisma.session.delete({ where: { id: sessionId } });

  await prisma.userSecurityAuditLog.create({
    data: {
      userId: session.userId,
      ipAddress: metadata.ipAddress,
      userAgent: metadata.userAgent,
      type: UserSecurityAuditLogType.SIGN_OUT,
    },
  });
};
