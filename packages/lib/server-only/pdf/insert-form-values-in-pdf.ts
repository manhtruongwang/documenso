import fontkit from '@pdf-lib/fontkit';
import { PDFCheckBox, PDFDocument, PDFDropdown, PDFRadioGroup, PDFTextField } from 'pdf-lib';
import { NEXT_PUBLIC_WEBAPP_URL } from '../../constants/app';

export type InsertFormValuesInPdfOptions = {
  pdf: Buffer;
  formValues: Record<string, string | boolean | number>;
};

export const insertFormValuesInPdf = async ({ pdf, formValues }: InsertFormValuesInPdfOptions) => {
  const doc = await PDFDocument.load(pdf);

  // Register fontkit to enable custom font embedding
  doc.registerFontkit(fontkit);
  
  // Fetch and embed a font with Vietnamese character support
  let customFont: any;
  try {
    const fontBytes = await fetch(`${NEXT_PUBLIC_WEBAPP_URL()}/fonts/noto-sans.ttf`).then(
      async (res) => res.arrayBuffer()
    );
    
    customFont = await doc.embedFont(fontBytes);
    
    const form = doc.getForm();
    
    if (!form) {
      return pdf;
    }

    // Process fields first
    for (const [key, value] of Object.entries(formValues)) {
      try {
        const field = form.getField(key);

        if (!field) {
          continue;
        }

        if (typeof value === 'boolean' && field instanceof PDFCheckBox) {
          if (value) {
            field.check();
          } else {
            field.uncheck();
          }
        }

        if (field instanceof PDFTextField) {
          field.setText(value.toString());
          // Apply custom font to text fields specifically
          field.updateAppearances(customFont);
        }

        if (field instanceof PDFDropdown) {
          field.select(value.toString());
        }

        if (field instanceof PDFRadioGroup) {
          field.select(value.toString());
        }
      } catch (err) {
        if (err instanceof Error) {
          console.error(`Error setting value for field ${key}: ${err.message}`);
        } else {
          console.error(`Error setting value for field ${key}`);
        }
      }
    }

    // Only for text fields that might contain Vietnamese text,
    // override the updateFieldAppearances method
    const originalUpdateFieldAppearances = form.updateFieldAppearances.bind(form);
    form.updateFieldAppearances = function() {
      // Get all text fields
      const textFields = form.getFields()
        .filter(field => field instanceof PDFTextField)
        .map(field => field as PDFTextField);
      
      // Update appearance of text fields with custom font
      for (const textField of textFields) {
        textField.updateAppearances(customFont);
      }
      
      // For non-text fields, use default behavior
      return originalUpdateFieldAppearances();
    };
    
    // Call the form update to apply changes
    form.updateFieldAppearances();
    
  } catch (fontError) {
    console.error('Error embedding custom font:', fontError);
    
    // Fallback to regular processing without custom font
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
          if (value) {
            field.check();
          } else {
            field.uncheck();
          }
        }

        if (field instanceof PDFTextField) {
          field.setText(value.toString());
        }

        if (field instanceof PDFDropdown) {
          field.select(value.toString());
        }

        if (field instanceof PDFRadioGroup) {
          field.select(value.toString());
        }
      } catch (err) {
        if (err instanceof Error) {
          console.error(`Error setting value for field ${key}: ${err.message}`);
        } else {
          console.error(`Error setting value for field ${key}`);
        }
      }
    }
  }

  return await doc.save().then((buf) => Buffer.from(buf));
};
