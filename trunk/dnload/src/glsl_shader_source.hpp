#ifndef GLSL_SHADER_SOURCE_HPP
#define GLSL_SHADER_SOURCE_HPP

#include <sstream>

#if defined(DNLOAD_GLESV2)
#include "GLES2/gl2.h"
#else
#include "GL/glew.h"
#endif

/** \brief Shader parse.
 *
 * Shader source abstraction. Improves readability of very compressed GLSL shader code.
 */
class GlslShaderSource
{
  private:
    /** String stream containing the actual shader source. */
    std::ostringstream m_source;

    /** Container for C string. (if present). */
    char *m_string;

    /** Current indent. */
    unsigned m_indent;

  public:
    /** \brief Empty constructor.
     */
    GlslShaderSource() :
      m_string(NULL),
      m_indent(0) { }

    /** \brief Constructor.
     *
     * \param str1 First source string.
     */
    GlslShaderSource(const char *str1);

    /** \brief Destructor. */
    ~GlslShaderSource();

  public:
    /** \brief Get human-readable output.
     *
     * \return C string.
     */
    const char* c_str();

  private:
    /** \brief Add a string element.
     *
     * Modifies indent accordingly.
     *
     * \param op String to add.
     */
    void add(const std::string &op);

  public:
    /** \brief Get program pipeline info log.
     *
     * \param op Program pipeline id.
     * \return Program pipeline info log.
     */
    static std::string get_pipeline_info_log(GLuint op);

    /** \brief Get program info log.
     *
     * \param op Program id.
     * \return Program info log.
     */
    static std::string get_program_info_log(GLuint op);

    /** \brief Get program link status.
     *
     * \param op Program id.
     * \return True if linked successfully, false otherwise.
     */
    static bool get_program_link_status(GLuint op);

    /** \brief Get shader compile status.
     *
     * \param op Shader id.
     * \return True if compiled successfully, false otherwise.
     */
    static bool get_shader_compile_status(GLuint op);

    /** \brief Get shader info log.
     *
     * \param op Shader id.
     * \return Shader info log.
     */
    static std::string get_shader_info_log(GLuint op);

  public:
    /** \brief Get human-readable output.
     *
     * \return String.
     */
    std::string str() const
    {
      return m_source.str();
    }

  private:
    /** \brief Add a string element wrapper.
     *
     * \param op String to add.
     */
    void add(const char *op)
    {
      this->add(std::string(op));
    }
};

#endif
