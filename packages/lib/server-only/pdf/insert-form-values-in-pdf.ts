import fontkit from '@pdf-lib/fontkit';
import { PDFCheckBox, PDFDocument, PDFDropdown, PDFRadioGroup, PDFTextField } from 'pdf-lib';

import { NEXT_PUBLIC_WEBAPP_URL } from '../../constants/app';

export type InsertFormValuesInPdfOptions = {
  pdf: Buffer;
  formValues: Record<string, string | boolean | number>;
};

export const insertFormValuesInPdf = async ({ pdf, formValues }: InsertFormValuesInPdfOptions) => {
  const doc = await PDFDocument.load(pdf);
  doc.registerFontkit(fontkit);

  const fontBytes = await fetch(`${NEXT_PUBLIC_WEBAPP_URL()}/fonts/noto-sans.ttf`).then(
    async (res) => res.arrayBuffer(),
  );

  const customFont = await doc.embedFont(fontBytes);

  const form = doc.getForm();

  if (!form) {
    return pdf;
  }

  for (const [key, value] of Object.entries(formValues)) {
    try {
      const field = form.getField(key);

      if (!field) {
        continue;
      }

      if (typeof value === 'boolean' && field instanceof PDFCheckBox) {
        value ? field.check() : field.uncheck();
      }

      if (field instanceof PDFTextField) {
        field.setText(value.toString());
      }

      if (field instanceof PDFDropdown || field instanceof PDFRadioGroup) {
        field.select(value.toString());
      }
    } catch (err) {
      console.error(
        `Error setting value for field ${key}: ${err instanceof Error ? err.message : 'Unknown error'}`,
      );
    }
  }

  form.updateFieldAppearances(customFont);

  return Buffer.from(await doc.save());
};
