const { createClient } = require('contentful-management');

async function validate() {
  const client = createClient({
    accessToken: process.env.CONTENTFUL_TOKEN,
  });

  try {
    const space = await client.getSpace(process.env.CONTENTFUL_SPACE_ID);
    const environment = await space.getEnvironment(process.env.CONTENTFUL_ENVIRONMENT_ID);

    // Example: Check that a required content type exists
    const contentType = await environment.getContentType('blogPost');
    if (!contentType) {
      throw new Error('Content type "blogPost" does not exist.');
    }

    console.log('✅ Schema validation passed.');
  } catch (error) {
    console.error('Schema validation failed:', error.message);
    process.exit(1); // Fail step if validation fails
  }
}

validate();
