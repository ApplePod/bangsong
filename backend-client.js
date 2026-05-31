(function () {
  const DEFAULT_URL = "https://invprwpzxosrhegxsfec.supabase.co";
  const KEY_STORAGE = "supabase_anon_key";

  const state = {
    url: DEFAULT_URL,
    anonKey: localStorage.getItem(KEY_STORAGE) || "",
    client: null,
    mode: "mock",
    mockProjects: JSON.parse(localStorage.getItem("mock_projects") || "[]"),
    mockProjectQuestions: JSON.parse(localStorage.getItem("mock_project_questions") || "{}"),
  };

  const persistMock = () => {
    localStorage.setItem("mock_projects", JSON.stringify(state.mockProjects));
    localStorage.setItem("mock_project_questions", JSON.stringify(state.mockProjectQuestions));
  };

  const ensureSupabaseClient = () => {
    if (!state.anonKey || !window.supabase || !window.supabase.createClient) {
      state.mode = "mock";
      state.client = null;
      return null;
    }
    if (!state.client) {
      state.client = window.supabase.createClient(state.url, state.anonKey);
    }
    state.mode = "supabase";
    return state.client;
  };

  const setAnonKey = (key) => {
    state.anonKey = key || "";
    if (state.anonKey) localStorage.setItem(KEY_STORAGE, state.anonKey);
    else localStorage.removeItem(KEY_STORAGE);
    state.client = null;
    ensureSupabaseClient();
  };

  const getSessionUser = async () => {
    const client = ensureSupabaseClient();
    if (!client) return null;
    const { data } = await client.auth.getUser();
    return data?.user || null;
  };

  const ensureAuth = async () => {
    const client = ensureSupabaseClient();
    if (!client) return null;
    let user = await getSessionUser();
    if (user) return user;
    try {
      const { data } = await client.auth.signInAnonymously();
      return data?.user || null;
    } catch (_err) {
      return null;
    }
  };

  const signInAdmin = async ({ email, password }) => {
    const client = ensureSupabaseClient();
    if (!client) {
      throw new Error("Supabase anon key가 설정되지 않았습니다.");
    }
    const { data, error } = await client.auth.signInWithPassword({ email, password });
    if (error) throw error;
    return data?.user || null;
  };

  const signOut = async () => {
    const client = ensureSupabaseClient();
    if (!client) return;
    const { error } = await client.auth.signOut();
    if (error) throw error;
  };

  const generateCode = () =>
    Math.random().toString(36).slice(2, 10);

  const createProject = async ({ name, slug, description, testId }) => {
    const client = ensureSupabaseClient();
    if (!client) {
      const p = {
        id: crypto.randomUUID(),
        name,
        slug,
        description: description || "",
        access_code: generateCode(),
        test_id: testId || "mock-test",
        created_at: new Date().toISOString(),
      };
      state.mockProjects.unshift(p);
      state.mockProjectQuestions[p.id] = (window.DIAGNOSTIC_QUESTIONS || []).map((q) => ({
        id: crypto.randomUUID(),
        question_no: q.no,
        prompt: q.prompt,
        stem: q.stem,
        correct_choice_no: 1,
        is_active: true,
        choices: q.choices,
      }));
      persistMock();
      return p;
    }

    await ensureAuth();
    const { data, error } = await client.rpc("create_project_from_test", {
      p_test_id: testId,
      p_name: name,
      p_slug: slug,
      p_description: description || null,
    });
    if (error) throw error;
    const created = Array.isArray(data) ? data[0] : data;
    const project = await getProjectById(created.project_id);
    return project;
  };

  const listProjects = async () => {
    const client = ensureSupabaseClient();
    if (!client) return state.mockProjects;

    await ensureAuth();
    const { data, error } = await client
      .from("diagnostic_projects")
      .select("id, name, slug, description, access_code, is_active, created_at, test_id")
      .order("created_at", { ascending: false });
    if (error) throw error;
    return data || [];
  };

  const listTests = async () => {
    const client = ensureSupabaseClient();
    if (!client) {
      return [{ id: "mock-test", slug: "mock-test", title: "기본 테스트", is_active: true }];
    }
    const { data, error } = await client
      .from("diagnostic_tests")
      .select("id, slug, title, is_active")
      .eq("is_active", true)
      .order("created_at", { ascending: true });
    if (error) throw error;
    return data || [];
  };

  const getProjectById = async (projectId) => {
    const client = ensureSupabaseClient();
    if (!client) return state.mockProjects.find((p) => p.id === projectId) || null;

    const { data, error } = await client
      .from("diagnostic_projects")
      .select("id, name, slug, description, access_code, is_active, created_at, test_id")
      .eq("id", projectId)
      .single();
    if (error) throw error;
    return data;
  };

  const getProjectBySlug = async (slug) => {
    const client = ensureSupabaseClient();
    if (!client) return state.mockProjects.find((p) => p.slug === slug) || null;

    const { data, error } = await client
      .from("diagnostic_projects")
      .select("id, name, slug, description, access_code, is_active, created_at, test_id")
      .eq("slug", slug)
      .eq("is_active", true)
      .single();
    if (error) return null;
    return data;
  };

  const getProjectByCode = async (code) => {
    const client = ensureSupabaseClient();
    if (!client) return state.mockProjects.find((p) => p.access_code === code) || null;

    const { data, error } = await client
      .from("diagnostic_projects")
      .select("id, name, slug, description, access_code, is_active, created_at, test_id")
      .eq("access_code", code)
      .eq("is_active", true)
      .single();
    if (error) return null;
    return data;
  };

  const getProjectQuestions = async (projectId) => {
    const client = ensureSupabaseClient();
    if (!client) {
      return (state.mockProjectQuestions[projectId] || []).map((q) => ({
        id: q.id,
        question_no: q.question_no,
        prompt: q.prompt,
        stem: q.stem,
        is_active: q.is_active,
        project_question_choices: (q.choices || []).map((content, idx) => ({
          choice_no: idx + 1,
          content,
        })),
      }));
    }

    await ensureAuth();
    const { data, error } = await client
      .from("project_questions")
      .select(`
        id, question_no, prompt, stem, is_active, correct_choice_no,
        project_question_choices(choice_no, content)
      `)
      .eq("project_id", projectId)
      .eq("is_active", true)
      .order("question_no", { ascending: true });
    if (error) throw error;
    return data || [];
  };

  const updateProjectQuestion = async ({ projectQuestionId, prompt, stem, isActive }) => {
    const client = ensureSupabaseClient();
    if (!client) {
      Object.values(state.mockProjectQuestions).forEach((arr) => {
        const target = arr.find((q) => q.id === projectQuestionId);
        if (target) {
          if (typeof prompt === "string") target.prompt = prompt;
          if (typeof stem === "string") target.stem = stem;
          if (typeof isActive === "boolean") target.is_active = isActive;
        }
      });
      persistMock();
      return;
    }
    await ensureAuth();
    const payload = {};
    if (typeof prompt === "string") payload.prompt = prompt;
    if (typeof stem === "string") payload.stem = stem;
    if (typeof isActive === "boolean") payload.is_active = isActive;
    const { error } = await client.from("project_questions").update(payload).eq("id", projectQuestionId);
    if (error) throw error;
  };

  window.AppBackend = {
    getConfig: () => ({ url: state.url, anonKey: state.anonKey, mode: state.mode }),
    setAnonKey,
    getSessionUser,
    signInAdmin,
    signOut,
    ensureAuth,
    listTests,
    listProjects,
    createProject,
    getProjectById,
    getProjectBySlug,
    getProjectByCode,
    getProjectQuestions,
    updateProjectQuestion,
  };
})();
