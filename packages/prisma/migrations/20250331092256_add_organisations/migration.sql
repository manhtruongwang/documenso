-- AlterTable
ALTER TABLE "Document" ADD COLUMN "teamMemberId" INTEGER;
ALTER TABLE "Template" ADD COLUMN "teamMemberId" INTEGER;

-- DropForeignKey
ALTER TABLE "Subscription" DROP CONSTRAINT "Subscription_teamId_fkey";
ALTER TABLE "Subscription" DROP CONSTRAINT "Subscription_userId_fkey";

-- DropIndex
DROP INDEX "Subscription_teamId_key";
DROP INDEX "Subscription_userId_idx";

-- DropConstraints
ALTER TABLE "Subscription" DROP CONSTRAINT "teamid_or_userid_check";


-- 1. Ensure all users have a URL by setting a default CUID
UPDATE "User"
SET "url" = gen_random_uuid()
WHERE "url" IS NULL;

-- 2. Make User URL required
ALTER TABLE "User" ALTER COLUMN "url" SET NOT NULL;

-- 3. Add isPersonal boolean to Team table with default false
ALTER TABLE "Team" ADD COLUMN "isPersonal" BOOLEAN NOT NULL DEFAULT false;

-- 4. Create a personal team for every user
INSERT INTO "Team" ("name", "url", "createdAt", "ownerUserId", "avatarImageId", "isPersonal")
SELECT
  'Personal Team',
  "url", -- Use the user's URL directly
  NOW(),
  "id",
  "avatarImageId",
  true -- Set isPersonal to true for these personal teams
FROM "User" u;

-- 5. Add each user as an ADMIN member of their own team
INSERT INTO "TeamMember" ("teamId", "userId", "role", "createdAt")
SELECT t."id", u."id", 'ADMIN', NOW()
FROM "User" u
JOIN "Team" t ON t."ownerUserId" = u."id"
WHERE t."isPersonal" = true;

-- 6. Migrate user's documents to their personal team and set teamMemberId
UPDATE "Document"
SET
  "teamId" = t."id",
  "teamMemberId" = tm."id"
FROM "Team" t, "TeamMember" tm
WHERE tm."teamId" = t."id"
  AND tm."userId" = "Document"."userId"
  AND "Document"."userId" = t."ownerUserId"
  AND "Document"."teamId" IS NULL
  AND t."isPersonal" = true;

-- 7. Migrate team documents to be associated with a teamMember
UPDATE "Document" d
SET "teamMemberId" = tm."id"
FROM "TeamMember" tm
WHERE d."teamId" = tm."teamId"
  AND d."teamMemberId" IS NULL
  AND EXISTS (
    SELECT 1 FROM "Team" t
    WHERE t."id" = d."teamId"
    AND d."userId" = tm."userId"
  );

-- 8. Migrate user's templates to their team and set teamMemberId
UPDATE "Template"
SET
  "teamId" = t."id",
  "teamMemberId" = tm."id"
FROM "Team" t, "TeamMember" tm
WHERE tm."teamId" = t."id"
  AND tm."userId" = "Template"."userId"
  AND "Template"."userId" = t."ownerUserId"
  AND "Template"."teamId" IS NULL
  AND t."isPersonal" = true;


-- 9. Migrate team templates to be associated with a teamMember
UPDATE "Template" template
SET "teamMemberId" = tm."id"
FROM "TeamMember" tm
WHERE template."teamId" = tm."teamId"
  AND template."teamMemberId" IS NULL
  AND EXISTS (
    SELECT 1 FROM "Team" t
    WHERE t."id" = template."teamId"
    AND template."userId" = tm."userId"
  );

-- 8. Migrate user's webhooks to their team
UPDATE "Webhook" w
SET "teamId" = t."id"
FROM "Team" t
WHERE w."userId" = t."ownerUserId" AND w."teamId" IS NULL;

-- 9. Migrate user's API tokens to their team
UPDATE "ApiToken" at
SET "teamId" = t."id"
FROM "Team" t
WHERE at."userId" = t."ownerUserId" AND at."teamId" IS NULL;

-- 10. Migrate user's subscription to their team
UPDATE "Subscription" s
SET "teamId" = t."id"
FROM "Team" t
WHERE s."userId" = t."ownerUserId" AND s."teamId" IS NULL;

-- /*
--   BEGIN SCHEMA MIGRATION
-- */


-- CreateEnum
CREATE TYPE "OrganisationType" AS ENUM ('PERSONAL', 'ORGANISATION');

-- CreateEnum
CREATE TYPE "OrganisationMemberRole" AS ENUM ('ADMIN', 'MANAGER', 'MEMBER');

-- CreateEnum
CREATE TYPE "OrganisationMemberInviteStatus" AS ENUM ('ACCEPTED', 'PENDING', 'DECLINED');

-- DropForeignKey
ALTER TABLE "Document" DROP CONSTRAINT "Document_userId_fkey";

-- DropForeignKey
ALTER TABLE "Team" DROP CONSTRAINT "Team_ownerUserId_fkey";

-- DropForeignKey
ALTER TABLE "TeamMemberInvite" DROP CONSTRAINT "TeamMemberInvite_teamId_fkey";

-- DropForeignKey
ALTER TABLE "TeamTransferVerification" DROP CONSTRAINT "TeamTransferVerification_teamId_fkey";

-- DropForeignKey
ALTER TABLE "Template" DROP CONSTRAINT "Template_userId_fkey";

-- DropIndex
DROP INDEX "Document_userId_idx";


-- DropIndex
DROP INDEX "Team_customerId_key";

-- AlterTable
ALTER TABLE "ApiToken" ADD COLUMN     "organisationId" TEXT;

-- AlterTable
ALTER TABLE "Document" DROP COLUMN "userId";

-- AlterTable
ALTER TABLE "Template" DROP COLUMN "userId";

-- AlterTable
ALTER TABLE "Subscription" DROP COLUMN "userId",
ADD COLUMN     "organisationId" TEXT;


-- AlterTable
ALTER TABLE "Team" DROP COLUMN "customerId",
ADD COLUMN     "organisationId" TEXT;

-- AlterTable
ALTER TABLE "Webhook" ADD COLUMN     "organisationId" TEXT;

-- DropTable
DROP TABLE "TeamMemberInvite";

-- DropTable
DROP TABLE "TeamTransferVerification";

-- DropEnum
DROP TYPE "TeamMemberInviteStatus";

-- CreateTable
CREATE TABLE "Organisation" (
    "id" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,
    "type" "OrganisationType" NOT NULL,
    "name" TEXT NOT NULL,
    "avatarImageId" TEXT,
    "customerId" TEXT,
    "ownerUserId" INTEGER NOT NULL,

    "teamId" INTEGER, -- TEMPORARY COLUMN FOR MIGRATION PURPOSES

    CONSTRAINT "Organisation_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "OrganisationMember" (
    "id" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,
    "role" "OrganisationMemberRole" NOT NULL,
    "userId" INTEGER NOT NULL,
    "organisationId" TEXT NOT NULL,

    CONSTRAINT "OrganisationMember_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "OrganisationMemberInvite" (
    "id" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "email" TEXT NOT NULL,
    "token" TEXT NOT NULL,
    "role" "OrganisationMemberRole" NOT NULL,
    "status" "OrganisationMemberInviteStatus" NOT NULL DEFAULT 'PENDING',
    "organisationId" TEXT NOT NULL,

    CONSTRAINT "OrganisationMemberInvite_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "Organisation_customerId_key" ON "Organisation"("customerId");

-- CreateIndex
CREATE UNIQUE INDEX "OrganisationMember_userId_organisationId_key" ON "OrganisationMember"("userId", "organisationId");

-- CreateIndex
CREATE UNIQUE INDEX "OrganisationMemberInvite_token_key" ON "OrganisationMemberInvite"("token");

-- CreateIndex
CREATE UNIQUE INDEX "OrganisationMemberInvite_organisationId_email_key" ON "OrganisationMemberInvite"("organisationId", "email");

-- CreateIndex
CREATE INDEX "Document_teamMemberId_idx" ON "Document"("teamMemberId");

-- CreateIndex
CREATE INDEX "Subscription_organisationId_idx" ON "Subscription"("organisationId");

-- AddForeignKey
ALTER TABLE "Webhook" ADD CONSTRAINT "Webhook_organisationId_fkey" FOREIGN KEY ("organisationId") REFERENCES "Organisation"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "ApiToken" ADD CONSTRAINT "ApiToken_organisationId_fkey" FOREIGN KEY ("organisationId") REFERENCES "Organisation"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Subscription" ADD CONSTRAINT "Subscription_organisationId_fkey" FOREIGN KEY ("organisationId") REFERENCES "Organisation"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Document" ADD CONSTRAINT "Document_teamMemberId_fkey" FOREIGN KEY ("teamMemberId") REFERENCES "TeamMember"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Organisation" ADD CONSTRAINT "Organisation_avatarImageId_fkey" FOREIGN KEY ("avatarImageId") REFERENCES "AvatarImage"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Organisation" ADD CONSTRAINT "Organisation_ownerUserId_fkey" FOREIGN KEY ("ownerUserId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "OrganisationMember" ADD CONSTRAINT "OrganisationMember_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "OrganisationMember" ADD CONSTRAINT "OrganisationMember_organisationId_fkey" FOREIGN KEY ("organisationId") REFERENCES "Organisation"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "OrganisationMemberInvite" ADD CONSTRAINT "OrganisationMemberInvite_organisationId_fkey" FOREIGN KEY ("organisationId") REFERENCES "Organisation"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Team" ADD CONSTRAINT "Team_organisationId_fkey" FOREIGN KEY ("organisationId") REFERENCES "Organisation"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Template" ADD CONSTRAINT "Template_teamMemberId_fkey" FOREIGN KEY ("teamMemberId") REFERENCES "TeamMember"("id") ON DELETE CASCADE ON UPDATE CASCADE;



-- CUSTOM MIGRATIONS

-- Create Organizations for each Team and update Team records with their Organisation IDs
WITH new_organisations AS (
  INSERT INTO "Organisation" ("id", "createdAt", "updatedAt", "type", "name", "avatarImageId", "ownerUserId", "teamId")
  SELECT
    gen_random_uuid(),
    t."createdAt",
    NOW(),
    CASE WHEN t."isPersonal" THEN 'PERSONAL'::"OrganisationType" ELSE 'ORGANISATION'::"OrganisationType" END,
    t."name",
    t."avatarImageId",
    t."ownerUserId",
    t."id"
  FROM "Team" t
  RETURNING "id", "ownerUserId", "teamId"
)
UPDATE "Team" t
SET "organisationId" = o."id"
FROM new_organisations o
WHERE o."teamId" = t."id";



-- Create OrganizationMembers for each TeamMember
INSERT INTO "OrganisationMember" ("id", "createdAt", "updatedAt", "role", "userId", "organisationId")
SELECT
  gen_random_uuid(),
  tm."createdAt",
  NOW(),
  CASE WHEN tm."userId" = t."ownerUserId" THEN 'ADMIN'::"OrganisationMemberRole" ELSE 'MEMBER'::"OrganisationMemberRole" END,
  tm."userId",
  t."organisationId"
FROM "TeamMember" tm, "Team" t
WHERE t."id" = tm."teamId";


-- Migrate team subscriptions to the organisation level
UPDATE "Subscription" s
SET "organisationId" = t."organisationId"
FROM "Team" t
WHERE s."teamId" = t."id";

-- Drop temp columns
ALTER TABLE "Organisation" DROP COLUMN "teamId";
ALTER TABLE "Team" DROP COLUMN "isPersonal";

-- REAPPLY NOT NULL to any temporary nullable columns
ALTER TABLE "Team" ALTER COLUMN "organisationId" SET NOT NULL;
ALTER TABLE "Subscription" ALTER COLUMN "organisationId" SET NOT NULL;
ALTER TABLE "Document" ALTER COLUMN "teamMemberId" SET NOT NULL;
ALTER TABLE "Template" ALTER COLUMN "teamMemberId" SET NOT NULL;

-- Remove ownerUserId from Team table
ALTER TABLE "Team" DROP COLUMN "ownerUserId";
ALTER TABLE "User" DROP COLUMN "url";
ALTER TABLE "Subscription" DROP COLUMN "teamId";
