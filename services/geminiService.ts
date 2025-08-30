import { GoogleGenAI } from "@google/genai";

let ai: GoogleGenAI | null = null;

const getAi = (): GoogleGenAI | null => {
  if (ai) {
    return ai;
  }
  const apiKey = process.env.API_KEY;
  if (!apiKey) {
    return null;
  }
  ai = new GoogleGenAI({ apiKey });
  return ai;
};


export const reviewCodeWithGemini = async (code: string, language: string): Promise<string> => {
  const genai = getAi();
  if (!genai) {
      return "CRITICAL ERROR: API_KEY environment variable not found. The application cannot function without it.";
  }

  if (!code.trim()) {
    return "Please provide some code to review.";
  }

  const prompt = `
    You are an expert senior software engineer and a world-class code reviewer.
    Your task is to provide a comprehensive and constructive review of the following ${language} code.

    Analyze the code for the following aspects:
    1.  **Bugs and Errors:** Identify any potential bugs, logical errors, or edge cases that are not handled.
    2.  **Performance:** Suggest optimizations for performance bottlenecks or inefficient code.
    3.  **Security:** Point out any potential security vulnerabilities.
    4.  **Best Practices & Readability:** Check for adherence to language-specific best practices, code style, and overall readability. Suggest improvements for clarity and maintainability.
    5.  **Architecture:** Comment on the overall structure and design, if applicable.

    Provide your feedback in Markdown format. Structure your review with clear headings for each category (e.g., ### Bugs, ### Performance).
    For each point, explain the issue and suggest a specific code change or improvement. Use code snippets where helpful.
    If you find no issues in a category, state "No issues found."

    Here is the code to review:
    \`\`\`${language}
    ${code}
    \`\`\`
  `;

  try {
    const response = await genai.models.generateContent({
      model: 'gemini-2.5-flash',
      contents: prompt,
    });
    return response.text;
  } catch (error) {
    console.error("Error calling Gemini API:", error);
    if (error instanceof Error) {
        return `An error occurred while communicating with the Gemini API: ${error.message}`;
    }
    return "An unknown error occurred while communicating with the Gemini API.";
  }
};