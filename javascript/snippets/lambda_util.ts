// @types/aws-lambda
import { APIGatewayProxyEventV2, APIGatewayProxyResultV2, Handler } from "aws-lambda";

type ProxyHandler = Handler<APIGatewayProxyEventV2, APIGatewayProxyResultV2>;

export type ApiInput = {
  method: string;
  pathParts: string[];
  headers: Record<string, string | number | boolean | undefined>;
  parameters?: Record<string, string | undefined>;
  body?: string;
};

export type ApiResponse = {
  statusCode?: number;
  headers?: Record<string, string>;
  body?: string;
};

function buildApiInput(event: APIGatewayProxyEventV2): ApiInput {
  return {
    method: event.requestContext.http.method,
    pathParts: event.requestContext.http.path.split("/"),
    headers: event.headers,
    parameters: event.queryStringParameters,
    body: event.body,
  };
}

export type ApiHandler = (input: ApiInput) => Promise<ApiResponse>;

const exampleHandler: ApiHandler = async (input): Promise<ApiResponse> => {
  const response: ApiResponse = {
    statusCode: 200,
    body: "hello world! " + JSON.stringify(input),
  };
  return response;
};

/** Used to simplify the types considerably */
export function lambdaWrapper(fn: ApiHandler): ProxyHandler {
  const lambda_handler: ProxyHandler = async (event, _context) =>
    fn(buildApiInput(event));
  return lambda_handler;
}
