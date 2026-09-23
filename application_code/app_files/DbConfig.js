const { SecretsManagerClient, GetSecretValueCommand } = require("@aws-sdk/client-secrets-manager");

const secret_name = process.env.SECRET_NAME;
const region = process.env.REGION;

async function getDbSecret() {
    // Local/Docker Compose configuration: when DB_HOST is provided directly
    // via the environment, skip AWS Secrets Manager entirely so the stack
    // can run without AWS credentials.
    if (process.env.DB_HOST) {
        console.log('[DbConfig] Using environment-provided DB configuration (local/dev mode)');
        return {
            DB_HOST: process.env.DB_HOST,
            DB_PORT: process.env.DB_PORT || 3306,
            DB_USER: process.env.DB_USER,
            DB_PWD: process.env.DB_PASSWORD,
            DB_DATABASE: process.env.DB_NAME || 'webappdb'
        };
    }

    console.log(`[DbConfig] Fetching secret: ${secret_name} in region: ${region}`);
    const client = new SecretsManagerClient({ region: region });
    let response;

    try {
        response = await client.send(
            new GetSecretValueCommand({
                SecretId: secret_name,
            })
        );
    } catch (error) {
        throw error;
    }

    const secret = JSON.parse(response.SecretString);

    const [host, port] = secret.endpoint.split(':');

    return {
        DB_HOST: host,
        DB_PORT: port || 3306,
        DB_USER: secret.username,
        DB_PWD: secret.password,
        DB_DATABASE: secret.db_name || 'webappdb'
    };
}

module.exports = { getDbSecret };