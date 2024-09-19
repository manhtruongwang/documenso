import { Trans } from '@lingui/macro';

import { setupI18nSSR } from '@documenso/lib/client-only/providers/i18n.server';
import { getRequiredServerComponentSession } from '@documenso/lib/next-auth/get-server-component-session';
import { isAdmin } from '@documenso/lib/next-auth/guards/is-admin';

import { LeaderboardTable } from './data-table-leaderboard';
import { search } from './fetch-leaderboard.actions';

type AdminLeaderboardProps = {
  searchParams?: {
    search?: string;
    page?: number;
    perPage?: number;
  };
};

export default async function Leaderboard({ searchParams = {} }: AdminLeaderboardProps) {
  setupI18nSSR();

  const { user } = await getRequiredServerComponentSession();

  if (!isAdmin(user)) {
    throw new Error('Unauthorized');
  }

  const page = Number(searchParams.page) || 1;
  const perPage = Number(searchParams.perPage) || 10;
  const searchString = searchParams.search || '';

  const { signingVolume, totalPages } = await search(searchString, page, perPage);

  return (
    <div>
      <h2 className="text-4xl font-semibold">
        <Trans>Signing Volume</Trans>
      </h2>
      <div className="mt-8">
        <LeaderboardTable
          signingVolume={signingVolume}
          totalPages={totalPages}
          page={page}
          perPage={perPage}
        />
      </div>
    </div>
  );
}
