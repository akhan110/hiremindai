# How to Use HireMind AI

Welcome to HireMind AI! This guide will walk you through the process of setting up the application, configuring your AI preferences, and analyzing candidate resumes to find the perfect fit for your open roles.

## 1. Initial Setup (Onboarding)

When you first launch the application, you will be guided through a 5-step onboarding process to configure the AI for your specific company and needs.

*   **Step 1: Company Profile**: Enter your **Company Name**, **Industry**, and **Team Size**. This context helps the AI understand your company's culture and what kind of candidate might fit best.
*   **Step 2: Evaluation Rules**: Provide custom instructions or a "persona" for the AI. For example, you can tell it to *"Always prioritize candidates with Flutter experience"* or *"Penalize gaps in employment"*.
*   **Step 3: Scoring Weights**: Adjust the sliders to determine how the final match score is calculated. You can weigh the importance of **Technical Skills**, **Experience & Pedigree**, and **Culture Fit & Soft Skills**.
*   **Step 4: Automation Settings**: Set an **Auto-Shortlist Cutoff** score. Any candidate who scores at or above this percentage will automatically be moved to your Shortlisted pipeline.
*   **Step 5: AI Providers**: Enter your API key for **OpenAI** (or Claude). Select your preferred AI provider to power the resume extraction and analysis. *Note: The API key is stored locally in your browser/device.*

Once you've completed these steps, click **Finish Setup** to proceed to the main Dashboard.

## 2. The Dashboard

The Dashboard is where the magic happens. Here, you will provide the job requirements and the candidate resumes.

*   **Step 1: Job Description**: In the left panel, paste the full job description for the role you are hiring for. 
    *   *Tip: You can use the **AI Optimize** button to let the AI automatically refine and structure your job description for better matching.*
*   **Step 2: Source Candidates**: Drag and drop your candidate resumes into the upload area, or click to browse your files. 
    *   Supported formats include **PDF**, **TXT**, and **DOCX**. 
    *   You can upload multiple resumes at once.

## 3. Analyzing Candidates

Once you have your job description pasted and your resumes uploaded, click the **Analyze Candidates** button.

The AI pipeline will then:
1.  Extract the key requirements from your job description.
2.  Extract the skills and experience from each uploaded resume.
3.  Compare each candidate against the job requirements using the scoring weights you defined during setup.
4.  Rank the candidates from highest match score to lowest.

## 4. Reviewing the Results

After the analysis is complete, the right panel will populate with **AI-Ranked Candidates**.

*   **Candidate Cards**: Each candidate has a card showing their name, overall match score, and current pipeline status.
*   **Detailed View**: Click on a candidate's card to expand it. Here you will find a deep dive into the AI's analysis, including:
    *   **Score Breakdown**: How they scored on Skills, Experience, and Culture Fit.
    *   **Summary**: A brief overview of the candidate's profile.
    *   **Strengths & Gaps**: What makes them a strong fit and where they might fall short.
    *   **Interview Questions**: Custom-generated interview questions tailored to the candidate's specific gaps or areas of interest.

*   **Filtering & Sorting**: Use the filters at the top (e.g., Software, Senior, Remote) and the sort dropdown (Score, Experience, Name) to quickly find specific candidates.

## 5. Managing Your Pipeline

Use the navigation tabs at the top of the screen to manage your candidates:

*   **Dashboard**: The main view for uploading and analyzing new candidates.
*   **Candidate Pool**: A list of all candidates you have analyzed.
*   **Pipeline**: A Kanban-style board showing your shortlisted candidates (those who met your auto-shortlist cutoff) and allowing you to track their progress through the interview stages.
*   **Reports**: High-level metrics and insights about your candidate pool.

## Updating Your Settings

If you ever need to change your API keys, scoring weights, or company profile, simply click on your user profile or the "Provider Connected" badge in the top right corner of the navigation bar to return to the Onboarding Setup screen.
